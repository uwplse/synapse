#lang racket

(require "search-worker.rkt" "../engine/metasketch.rkt" "solver+.rkt" "verifier.rkt" "util.rkt"
         "../bv/lang.rkt"
         "../../benchmarks/all.rkt" "../metasketches/imetasketch.rkt"
         "log.rkt"
         (only-in rosette/solver/solution model)
         rosette/solver/kodkod/kodkod (rename-in rosette/config/log [log-info log-info-r])
         syntax/modresolve racket/runtime-path racket/serialize)

(provide search)

; This procedure implements the top-level search over a metasketch.
;
; * metasketch : constant? is the metasketch over which to search.
;
; * threads : natural/c is the number of threads to run in parallel.
;
; * timeout : natural/c is the timeout for individual sketches in the
; metasketch, in seconds.
;
; * bitwidth : natural/c is the bit-width to finitize to.
;
; * bit-widening : (or/c #f (listof natural/c -1)) is a list of intermediate
;   bitwidths to attempt first, or #f if bit widening should not occur.
;   The list must be sorted and increasing, and should not include the final
;   full bitwidth.
;
; * exchange-samples : boolean? decides whether to share CEXs between solvers
;
; * use-structure : boolean? decides whether to add structure constraints
(define (search
         #:metasketch ms-spec
         #:threads [threads 1]
         #:timeout [timeout 10]
         #:bitwidth [bw 32]
         #:widening [bit-widening #f]
         #:exchange-samples [exchange-samples #t]
         #:exchange-costs [exchange-costs #t]
         #:use-structure [use-structure #t]
         #:incremental [incremental #t]
         #:synthesizer [synthesizer% 'kodkod-incremental%]
         #:verifier [verifier% 'kodkod%]
         #:verbose [verbosity #f])
  ; record start time and set up logging
  (log-start-time (current-inexact-milliseconds))
  (logging? verbosity)

  ; create our local copy of the metasketch
  (define ms (eval-metasketch ms-spec))
  (unless (imeta? ms)
    (raise-arguments-error 'search "need an indexed metasketch" "ms" ms))

  ; check arguments
  (unless (>= threads 1)
    (raise-arguments-error 'search "threads must be positive" "threads" threads))

  ;; results -------------------------------------------------------------------

  ; results : sketch? ↦ (or/c program? boolean?)
  ; results[S] is a program? if S is SAT, #t if S was proved UNSAT, or #f if S timed out
  (define results (make-hash))
  ; best solution and cost found so far
  (define best-program #f)
  (define best-cost +inf.0)
  ; samples : (hash/c integer? (listof (listof number?)))
  ; samples[bw] is a list of samples collected at a given bitwidth.
  ; each sample is a list of length (length (inputs ms)), which can be inflated
  ;   to a solution? by calling inflate-sample
  (define samples (make-hash))
  (define (count-samples) (for/sum ([v (hash-values samples)]) (length v)))

  ;; search state --------------------------------------------------------------

  ; workers : (vectorof place-channel?)
  ; the worker places
  (define workers (make-vector threads #f))
  
  ; worker->sketch : (vectorof sketch?)
  ; tracks which sketch each worker is currently running
  (define worker->sketch (make-vector threads #f))
  ; sketch->worker : (hash/c sketch? exact-nonnegative-integer?)
  ; tracks which worker each running sketch is on (inverse of worker->sketch)
  (define sketch->worker (make-hash))

  ; the stream of sketches remaining to try
  (define sketch-set (sketches ms best-cost))
  (define sketch-stream (set->stream sketch-set))

  ;; helper methods ------------------------------------------------------------

  ; launch a sketch on a specified worker
  (define (launch-sketch sketch worker-id)
    (unless (false? (vector-ref worker->sketch worker-id))
      (raise-arguments-error 'launch-sketch "attempt to launch sketch on occupied worker"))
    (define idx (isketch-index sketch))
    (define pch (vector-ref workers worker-id))
    (log-search "starting sketch ~a on worker ~a [~a remaining; ~a complete; ~a samples]"
                sketch worker-id (sketches-remaining) (hash-count results) (count-samples))
    (place-channel-put pch `(sketch ,idx ,best-cost ,samples))
    (vector-set! worker->sketch worker-id sketch)
    (hash-set! sketch->worker sketch worker-id))

  ; find the first available worker
  (define (next-available-worker)
    (let loop ([idx 0])
      (cond [(false? (vector-ref worker->sketch idx)) idx]
            [(= idx (sub1 threads)) (error "no available workers")]
            [else (loop (add1 idx))])))
  
  ; launch the next sketch on an available worker, if there are sketches remaining
  (define (launch-next-sketch)
    (let loop ()
      (unless (stream-empty? sketch-stream)
        (define sketch (stream-first sketch-stream))
        (set! sketch-stream (stream-rest sketch-stream))
        (if (or (hash-has-key? results sketch) (hash-has-key? sketch->worker sketch))
            (loop)
            (launch-sketch sketch (next-available-worker))))))

  ; announce that a sketch is satisfiable with a given program as solution
  (define (sketch-sat sketch prog cost)
    (hash-set! results sketch prog)
    (when (< cost best-cost)
      (new-best-cost cost prog)))

  ; announce that a sketch is unsatisfiable
  (define (sketch-unsat sketch)
    (define worker-id (hash-ref sketch->worker sketch))
    (stop-working worker-id)
    (unless (hash-has-key? results sketch)
      (hash-set! results sketch #t))
    (launch-next-sketch))

  ; announce that a sketch timed out
  (define (sketch-timeout sketch)
    (define worker-id (hash-ref sketch->worker sketch))
    (stop-working worker-id)
    (unless (hash-has-key? results sketch)
      (hash-set! results sketch #f))
    (launch-next-sketch))

  ; announce a new cost constraint to all running workers, and stop working on
  ; sketches for which the new cost constraint is trivially unsat
  (define (new-best-cost c prog)
    (set! best-cost c)
    (set! best-program prog)
    (set! sketch-set (sketches ms best-cost))
    (set! sketch-stream (set->stream sketch-set))
    (log-search "new best cost ~a; ~a sketches remaining" best-cost (sketches-remaining))
    (for ([worker-id threads][pch workers][sketch worker->sketch]
          #:unless (false? sketch))
      (cond [(set-member? sketch-set sketch)
             (cond [exchange-costs 
                    (place-channel-put pch `(cost ,best-cost))]
                   [else  ; if not exchanging costs, need to restart sketch
                    (stop-working worker-id)
                    (launch-sketch sketch worker-id)])]
            [else
             (unless (hash-has-key? results sketch)
               (hash-set! results sketch #t))
             (log-search "killing ~a because it's no longer in the set" sketch)
             (stop-working worker-id)
             (launch-next-sketch)])))

  ; announce a new set of samples to all running threads
  (define (new-samples bw samps)
    (when exchange-samples
      (hash-set! samples bw
                 (remove-duplicates (append samps (hash-ref samples bw '()))))
      (for ([pch workers][sketch worker->sketch]
            #:unless (false? sketch))
        (place-channel-put pch `(samples ,samples)))))

  ; tell a worker to stop doing work, and free it up for reuse
  (define (stop-working worker-id)
    (define sketch (vector-ref worker->sketch worker-id))
    (define pch (vector-ref workers worker-id))
    (place-channel-put pch `(kill))
    (hash-remove! sketch->worker sketch)
    (vector-set! worker->sketch worker-id #f))

  ; count sketches remaining to run
  (define (sketches-remaining)
    (define already-run (for/sum ([S (hash-keys results)]) (if (set-member? sketch-set S) 1 0)))
    (- (set-count sketch-set) already-run))


  ;; search body ---------------------------------------------------------------

  (log-search "START: sketches to try: ~a" (sketches-remaining))

  ; initialize the workers
  (for ([worker-id threads])
    (define pch (place channel (search-worker channel)))
    (place-channel-put pch `(config ,worker-id ,(log-start-time) ,timeout ,verbosity
                                    ,bw ,bit-widening
                                    ,exchange-samples ,exchange-costs ,use-structure ,incremental
                                    ,synthesizer% ,verifier%))
    (place-channel-put pch `(metasketch ,ms-spec))
    (vector-set! workers worker-id pch))
  
  ; send sketches to each worker
  (for ([worker-id threads])
    (launch-next-sketch))

  ; wait for a place to send us a message
  (let loop ()
    (match (apply sync 
             (for/list ([pch workers][worker-id threads]) 
               (wrap-evt pch (λ (res) (cons worker-id res)))))
      [(cons worker-id result)
       (define sketch (vector-ref worker->sketch worker-id))
       (define idx (second result))  ; all messages are '(TYPE idx ...)
       ; make sure we're still running the same sketch (otherwise msg is redundant)
       (when (and (not (false? sketch)) (equal? idx (isketch-index sketch)))
         (match result
           [(list 'sat idx c prog-ser bw samps)
            (define prog (deserialize prog-ser))
            (log-search "SAT ~a with cost ~a: ~v" sketch c prog)
            (new-samples bw samps)
            (sketch-sat sketch prog c)]
           [(list 'unsat idx bw samps)
            (log-search "UNSAT ~a" sketch)
            (new-samples bw samps)
            (sketch-unsat sketch)]
           [(list 'timeout idx)
            (log-search "TIMEOUT ~a" sketch)
            (sketch-unsat sketch)]))])
    (when (for/or ([sketch worker->sketch]) sketch)
      (loop)))

  (log-search "END: ~a completed; ~a remaining" (hash-count results) (sketches-remaining))
  
  (for ([pch workers])
    (place-kill pch)
    (place-wait pch))

  best-program
  )
