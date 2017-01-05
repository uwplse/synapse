#lang s-exp rosette

(require "util.rkt" "../opsyn/engine/verifier.rkt"
         rackunit "test-runner.rkt")

(current-bitwidth 32)

(define-symbolic* x y integer?)

; Trivial tests.
(define (test0)
 (test-case "trivial tests"
  (check-true (unsat? (verify)))
  (check-true (unsat? (verify #:pre '(#f))))
  (check-true (sat?   (verify #:post '(#f))))))

; Valid problem.
(define (test1)
 (test-case "valid problem"
  (check-true
   (unsat?
    (verify #:pre (list (not (= x 0)) (not (= y 0)))
            #:post (list (not (= x (+ x y))) (not (= y (+ x y)))))))))

; Invalid problem.
(define (test2)
 (test-case "invalid problem"
  (define sol 
    (verify #:post (list (not (= x (+ x y))))))
  (check-true (sat? sol))
  (check-equal? (sol y) 0)))


; Check the use of 32-bit arithmetic.
(define (test3)
 (test-case "32-bit arithmetic"
  (define sol 
    (verify #:pre (list (not (= x 0)))
            #:post (list (not (= x (- x))))))
  (check-true (sat? sol))
  (check-equal? (sol x) (- (expt 2 31)))))

(define/provide-test-suite verifier-tests
  (test0)
  (test1)
  (test2)
  (test3)
  )

(run-tests-quiet verifier-tests)
