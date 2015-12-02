#lang s-exp rosette

(require
  "../opsyn/engine/metasketch.rkt" "../opsyn/engine/eval.rkt" "../opsyn/engine/util.rkt"
  "../opsyn/bv/lang.rkt" "../opsyn/metasketches/imetasketch.rkt" 
  "../benchmarks/parrot/specs.rkt" "../benchmarks/parrot/kmeans.rkt" "../opsyn/engine/solver+.rkt" 
  rosette/solver/smt/z3
  rackunit "test-runner.rkt")

(current-bitwidth 32)

(current-subprocess-custodian-mode 'kill)


(define (synth M S)
  (parameterize ([current-custodian (make-custodian)])
    (with-handlers ([exn? (lambda (e) (custodian-shutdown-all (current-custodian)) (raise e))])
      (∃∀solver #:forall (inputs M) 
                #:pre (pre S) 
                #:post (append (post S (programs S)) (structure M S)))
      (begin0
        (second (thread-receive))  
        (custodian-shutdown-all (current-custodian))))))


(define (test-no-search idx)
 (test-case (format "ris ~a" idx)
  (unsafe-clear-terms!)
  (define M (dist3-ris #:quality (relaxed 1)))
  (define ref-cost (cost M dist3))
  (printf "~a cost: ~a\n" (object-name dist3) ref-cost)
  (define Ss (sketches M (cost M dist3)))
  (printf "sketches to try: ~a\n" (set-count Ss))
  (define S (isketch M idx))
  (printf "trying: ~a\n" S)
  (define sol (synth M S))
  (cond [(sat? sol)  (printf "~s\n"  (programs S sol)) sol]
        [else 
         (printf "unsat\n")])
  (check-true (sat? sol))))


(define/provide-test-suite kmeans-ris-tests
  (test-no-search '(9 0)))

; too slow to run by default
; (run-tests-quiet kmeans-ris-tests)
