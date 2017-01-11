#lang s-exp rosette

(require
  "../opsyn/engine/metasketch.rkt" "../opsyn/engine/eval.rkt" "../opsyn/engine/util.rkt"
  "../opsyn/bv/lang.rkt" "../benchmarks/hd/wcet.rkt" "../opsyn/engine/solver+.rkt" 
  "../opsyn/metasketches/iterator.rkt" "../opsyn/engine/search.rkt"
  rackunit "test-runner.rkt")


(current-subprocess-custodian-mode 'kill)

(current-bitwidth 32)

(define (synth M S)
  (parameterize ([current-custodian (make-custodian)])
    (with-handlers ([exn? (lambda (e) (custodian-shutdown-all (current-custodian)) (raise e))])
      (∃∀solver #:forall (inputs M) 
                #:pre (pre S) 
                #:post (append (post S (programs S)) (structure M S)))
      (begin0
        (second (thread-receive))  
        (custodian-shutdown-all (current-custodian))))))

(define (test-sgn M dynamic?)
 (test-case (format "hd-sgn ~a" dynamic?)
  (clear-terms!)
  (define-values (prog sol)
    (let loop ([sketches (sequence->stream (sketches M))])
      (define S (stream-first sketches))
      (printf "~a: " S)
      (define sol (synth M S))
      (cond [(sat? sol)  (printf "~s\n"  (programs S sol)) (values (programs S sol) sol)]
            [else 
             (printf "unsat\n")
             (loop (stream-rest sketches))])))
  (check-true (sat? sol))))

(define (test-search [threads 1] [dynamic? #t])
 (test-case (format "hd-sgn search ~a" dynamic?)
  (define M `(hd-sgn #:dynamic-cost? ,dynamic?))
  (check-not-false
    (search #:metasketch M
            #:threads threads
            #:timeout 30
            #:bitwidth (current-bitwidth)))))


(define/provide-test-suite hd-sgn-tests
  (test-sgn (hd-sgn #:dynamic-cost? #f) #f)
  (test-sgn (hd-sgn #:dynamic-cost? #t) #t))
  
(run-tests-quiet hd-sgn-tests)
