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
 (test-case (format "bdf ~a" idx)
  (unsafe-clear-terms!)
  (define M (dist3-bdf #:quality (relaxed 1)))
  (define ref-cost (cost M dist3))
  (define Ss (sketches M (cost M dist3)))
  (define S (isketch M idx))
  (define sol (synth M S))
  (check-true (sat? sol))))


(define/provide-test-suite kmeans-bdf-tests
  (test-no-search '(0)))

(run-tests-quiet kmeans-bdf-tests)
