#lang s-exp rosette

(require "../engine/metasketch.rkt" "solver+.rkt" "verifier.rkt" "util.rkt"
         "../../benchmarks/all.rkt" "../metasketches/imetasketch.rkt" "../bv/lang.rkt"
         "log.rkt" "sample.rkt"
         rosette/solver/kodkod/kodkod rosette/solver/smt/z3
         racket/serialize)

(provide search-worker)

(define-namespace-anchor a)
(define ns (namespace-anchor->namespace a))

(define (search-worker channel)
  (current-subprocess-custodian-mode 'kill)
  
  ; first thing we receive should be the configuration
  (match-define (list 'config my-id start-time timeout verbose
                      bitwidth bit-widening
                      exchange-samples? exchange-costs? use-structure? incremental?
                      synthesizer% verifier%)
    (place-channel-get channel))

  (parameterize ([log-start-time start-time]
                 [log-id my-id]
                 [logging? verbose])
    (set! synthesizer% (eval synthesizer% ns))
    (set! verifier% (eval verifier% ns))

    (log-search "worker started")

    ; next we get the metasketch
    (match-define (list 'metasketch ms-spec)
      (place-channel-get channel))
    (define ms (eval-metasketch ms-spec))

    (define cust #f)
    (define T #f)
    (define tre (thread-receive-evt))

    (define (kill-current-sketch)
      (unless (false? T)
        (custodian-shutdown-all cust)
        (set! cust #f)
        (set! T #f)))

    ; loop
    (let loop ()
      (match (sync channel tre)
        ; messages from local search are forwarded after serializing for place-channel
        [(== tre)
         (define msg (thread-receive))
         (define flat-msg
           (match msg
            [(list 'sat sketch c prog bw samps)
             (define idx (isketch-index sketch))
             (set! prog (serialize prog))
             (set! samps (map (curry deflate-sample (inputs ms)) samps))
             `(sat ,idx ,c ,prog ,bw ,samps)]
            [(list 'unsat sketch bw samps)
             (define idx (isketch-index sketch))
             (set! samps (map (curry deflate-sample (inputs ms)) samps))
             `(unsat ,idx ,bw ,samps)]
            [(list 'timeout sketch)
             (define idx (isketch-index sketch))
             `(timeout ,idx)]))
         (place-channel-put channel flat-msg)]
        [(list 'sketch idx best-cost samps)  ; start a new sketch
         (log-search "starting local search for ~a" idx)
         (kill-current-sketch)
         (define sketch (isketch ms idx))
         (define samples
          (for/hash ([(bw ss) samps])
            (values bw (map (curry inflate-sample (inputs ms)) ss))))
         (set! cust (make-custodian))
         (define me (current-thread))
         (set! T 
          (parameterize ([current-custodian cust])
            (thread (thunk (local-search ms sketch best-cost samples
                                         #:output me
                                         #:timeout timeout
                                         #:bitwidth bitwidth
                                         #:widening bit-widening
                                         #:exchange-samples? exchange-samples?
                                         #:exchange-costs? exchange-costs?
                                         #:use-structure? use-structure?
                                         #:incremental? incremental?
                                         #:synthesizer synthesizer%
                                         #:verifier verifier%)))))]
         [(list 'kill)  ; kill the current sketch
          (kill-current-sketch)]
         [(list 'samples samps)  ; new samples: inflate and send to local search
           (define samples
            (for/hash ([(bw ss) samps])
              (values bw (map (curry inflate-sample (inputs ms)) ss))))
           (thread-send T `(samples ,samples) #f)]  ; doesn't matter if T is dead
          [(list 'cost best-cost)  ; new best cost: send to local search
           (thread-send T `(cost ,best-cost) #f)])  ; doesn't matter if T is dead
      (loop))))

(define (local-search ms sketch best-cost samples
                      #:output output-thread
                      #:timeout timeout
                      #:bitwidth bitwidth
                      #:widening bit-widening
                      #:exchange-samples? exchange-samples?
                      #:exchange-costs? exchange-costs?
                      #:use-structure? use-structure?
                      #:incremental? incremental?
                      #:synthesizer synthesizer%
                      #:verifier verifier%)

  ; figure out the bitwidths to try
  (define minbw (min-bitwidth ms sketch))
  (define bitwidths
    (append (if (false? bit-widening) '() bit-widening) (list bitwidth)))
  (set! bitwidths
    (remove-duplicates (for/list ([bw bitwidths]) (max bw minbw))))

  (parameterize ([current-bitwidth (last bitwidths)])
    ; main loop to solve the sketch at widening bitwidths
    (let bw-loop ([bws bitwidths])
      (define bw (first bws))
      (define cust (make-custodian))
      ; start the ∃∀ solver at bitwidth bw
      (define sym-exec-start-time (current-inexact-milliseconds))
      (define-values (P P-pre P-post)
        (parameterize ([current-bitwidth bw])
          (define P (programs sketch))
          (define P-pre (pre sketch))
          (define P-post (post sketch P))
          (when (< best-cost +inf.0)
            (set! P-post (append P-post (list (< (cost ms P) best-cost)))))
          (when use-structure?
            (set! P-post (append P-post (structure ms sketch))))
          (values P P-pre P-post)))
      (define P-inputs (inputs ms))

      (log-search [sym-exec-start-time] "starting solver for sketch ~a at bitwidth ~a" sketch bw)

      (define my-start-time (current-inexact-milliseconds))
      (define alarm (alarm-evt (+ (current-inexact-milliseconds) (* timeout 1000))))
      (define T
        (parameterize ([current-bitwidth bw]
                       [current-custodian cust])
          (∃∀solver #:forall P-inputs
                    #:pre P-pre
                    #:post P-post
                    #:samples (hash-ref samples bw '())
                    #:synthesizer synthesizer%
                    #:verifier verifier%)))
      (define verif-cust #f)
      (define verif-solution #f)
      (define verif-samples #f)
      (define verif-thread #f)
      (define verif-start-time #f)

      ; wait for messages from either the solver or the global search
      (let msg-loop ()
        (define tre (thread-receive-evt))
        (match (sync tre alarm)
          [(== tre)  ; a message from the solver or global search
           (match (thread-receive)
             [(list (? thread? T) S I)  ; message from the solver
              (cond
                [(sat? S)  ; the sketch was SAT
                 (let* ([prog (programs sketch S)]
                        [c (cost ms prog)])
                   (log-search [my-start-time] "SAT ~a@bw~a with cost ~a: ~v" sketch bw c prog)
                   (cond [(equal? (rest bws) '())  ; is this the full bitwidth? if so, we're done
                          (thread-send output-thread `(sat ,sketch ,c ,prog ,bw ,I))
                          (msg-loop)]
                         [else  ; otherwise, we need to verify at current-bitwidth (i.e. (last bitwidths))
                          (let* ([P (programs sketch S)]
                                 [P-pre (pre sketch)]
                                 [P-post (post sketch P)])
                            (set! verif-solution S)
                            (set! verif-samples I)
                            (set! verif-cust (make-custodian))
                            (set! verif-start-time (current-inexact-milliseconds))
                            (parameterize ([current-custodian verif-cust])
                              (set! verif-thread (verify-async #:pre P-pre #:post P-post))))
                          (msg-loop)]))]
                [else  ; the sketch was UNSAT
                 (log-search [my-start-time] "UNSAT ~a@bw~a" sketch bw)
                 (custodian-shutdown-all cust)
                 (cond [(equal? (rest bws) '())  ; is this the full bitwidth? if so, we're done
                        (thread-send output-thread `(unsat ,sketch ,bw ,I))]
                       [else  ; otherwise, increase bitwidth and try again
                        (bw-loop (rest bws))])])]
             [(list (? thread? T) cex)  ; message from the verifier
              (cond [(unsat? cex)  ; no cex, so solution is verified, and we're done
                     (log-search [verif-start-time] "solution from bw ~a verified! ~a" bw sketch)
                     (define prog (programs sketch verif-solution))
                     (define c (cost ms prog))
                     (thread-send output-thread `(sat ,sketch ,c ,prog ,bw ,verif-samples))
                     (msg-loop)]
                    [else  ; a cex, so we need to increase bitwidth and try again
                     (log-search [verif-start-time] "solution from bw ~a failed to verify: ~a" bw sketch)
                     (bw-loop (rest bws))])]
             [(list 'cost c)  ; a new cost constraint from global search
              (set! best-cost c)
              (cond [incremental?
                     (parameterize ([current-bitwidth bw])
                       (define cost-constraint (< (cost ms (programs sketch)) c))
                       (thread-send T (list cost-constraint) #f))  ; forward to the incremental ∃∀solver
                     (msg-loop)]
                    [else
                     (log-search [my-start-time] "restarting solver with new cost ~a" c)
                     (custodian-shutdown-all cust)
                     (bw-loop bws)])]
             [(list 'samples samps)  ; a new set of samples from global search
              (set! samples samps)
              (thread-send T (hash-ref samples bw '()) #f)  ; forward to the incremental ∃∀solver
              (msg-loop)])]
          [(== alarm)  ; the timeout alarm
           (log-search [my-start-time] "TIMEOUT ~a@bw~a" sketch bw)
           (custodian-shutdown-all cust)
           (thread-send output-thread `(timeout ,sketch))])))))
