#lang s-exp rosette

(require
  "../opsyn/engine/metasketch.rkt" "../opsyn/engine/eval.rkt" "../opsyn/engine/util.rkt"
  "../opsyn/bv/lang.rkt" "../benchmarks/arrays/arraysearch.rkt" "../opsyn/engine/solver+.rkt" 
  "../opsyn/metasketches/iterator.rkt"
  rackunit "test-runner.rkt")

(current-subprocess-custodian-mode 'kill)

(current-bitwidth 6)

(define (synth M S)
  (parameterize ([current-custodian (make-custodian)])
    (with-handlers ([exn? (lambda (e) (custodian-shutdown-all (current-custodian)) (raise e))])
      (∃∀solver #:forall (inputs M) 
                #:pre (pre S) 
                #:post (append (post S (programs S)) (structure M S)))
      (begin0
        (second (thread-receive))  
        (custodian-shutdown-all (current-custodian))))))

(define (test-array-search M n)
 (test-case (format "array-search ~a" n)
  (unsafe-clear-terms!)
  (check-true
   (sat?
    (let loop ([sketches (sequence->stream (sketches M))])
      (define S (stream-first sketches))
      (printf "~a: " S)
      (define sol (synth M S))
      (cond [(sat? sol)
             (printf "~s\n"  (programs S sol))
             sol]
            [else 
             (printf "unsat\n")
             (loop (stream-rest sketches))]))))))


(define/provide-test-suite array-search-tests
  (for ([i (in-range 2 7)])
    (test-array-search (array-search i) i)))

(define/provide-test-suite array-search-tests/sum
  (for ([i (in-range 2 7)])
    (test-array-search (array-search i #:order enumerate-cross-product/sum) i)))

(run-tests-quiet array-search-tests)
(run-tests-quiet array-search-tests/sum)
