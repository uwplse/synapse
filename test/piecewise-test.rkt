#lang s-exp rosette

(require
  "../opsyn/metasketches/piecewise.rkt" "../opsyn/metasketches/imetasketch.rkt"
  "../opsyn/metasketches/cost.rkt" "../opsyn/metasketches/iterator.rkt"
  "../opsyn/engine/metasketch.rkt" "../opsyn/engine/eval.rkt" "../opsyn/engine/util.rkt"
  "../opsyn/bv/lang.rkt"
  "util.rkt"
  racket/generator
  rackunit "test-runner.rkt")

(current-bitwidth 32)

; A PF metasketch with 1 input that should produce the line y = x
(define M0
  (piecewise #:maxpieces 1
             #:maxdegree 1
             #:arity 1
             #:post (lambda (p inputs)
                      (begin
                        (assert (= (interpret p '(0)) 0))
                        (assert (= (interpret p '(1)) 1))))))

; A PF metasketch with 1 input that should produce the two polynomials
;  y = x^2, x ≥ 0
;  y = -x^2, x ≤ 0
(define M1
  (piecewise #:maxpieces 2
             #:maxdegree 2
             #:arity 1
             #:post (lambda (p inputs)
                      (begin
                        (assert (= (interpret p '(1)) 1))
                        (assert (= (interpret p '(2)) 4))
                        (assert (= (interpret p '(3)) 9))
                        (assert (= (interpret p '(-1)) -1))
                        (assert (= (interpret p '(-2)) -4))
                        (assert (= (interpret p '(-3)) -9))))))

; A PF metasketch with 2 inputs that should produce the two polynomials
;  y = x_1 - x_2^2, x_1 < 1 ∧ x_2 < 1
;  y = x_1 + x_2^2, otherwise
(define (p2 x1 x2)
  (if (and (< x1 1) (< x2 1))
      (- x1 (* x2 x2))
      (+ x1 (* x2 x2))))
(define M2
  (piecewise #:maxpieces 2
             #:maxdegree 2
             #:arity 2
             #:post (lambda (p inputs)
                      (for* ([x1 (in-range -3 4)][x2 (in-range -3 4)])
                        (assert (= (interpret p `(,x1 ,x2)) (p2 x1 x2)))))))

; A PF metasketch with 2 inputs that should produce the three polynomials
;  y = x_1 - x_2^2, x_1 < -2 ∧ x_2 < -2
;  y = x_1 + x_2^2, x_1 <  2 ∧ x_2 <  2
;  y = x_1 + x_2,   otherwise
(define (p3 x1 x2)
  (if (and (< x1 -2) (< x2 -2))
      (- x1 (* x2 x2))
      (if (and (< x1 2) (< x2 2))
          (+ x1 (* x2 x2))
          (+ x1 x2))))
(define M3
  (piecewise #:maxpieces 3
             #:maxdegree 2
             #:arity 2
             #:post (lambda (p inputs)
                      (for* ([x1 (in-range -5 5)][x2 (in-range -5 5)])
                        (assert (= (interpret p `(,x1 ,x2)) (p3 x1 x2)))))))

; The same as M3, but with no bounds on pieces/degree, to test iteration order.
; The number of points in the postcondition is important: we could overfit with
; n degree-0 polynomials.
(define M4
  (piecewise #:maxpieces +inf.0
             #:maxdegree +inf.0
             #:arity 2
             #:post (lambda (p inputs)
                      (for* ([x1 (in-range -5 5)][x2 (in-range -5 5)])
                        (assert (= (interpret p `(,x1 ,x2)) (p3 x1 x2)))))))

; A trivial piecewise function edge case: the constant y=2
(define M5
  (piecewise #:maxpieces 1
             #:maxdegree 0
             #:arity 1
             #:post (lambda (p inputs)
                      (begin
                        (assert (= (interpret p '(0)) 2))
                        (assert (= (interpret p '(1)) 2))))))

; The same as M3, but with a different search order
(define M6
  (piecewise #:maxpieces 3
             #:maxdegree 2
             #:arity 2
             #:post (lambda (p inputs)
                      (for* ([x1 (in-range -5 5)][x2 (in-range -5 5)])
                        (assert (= (interpret p `(,x1 ,x2)) (p3 x1 x2)))))
             #:order enumerate-cross-product/sum))

; Tests the interface of M5.
(define (test0)
 (test-case "M5 interface"
  (check equal? (length (inputs M5)) 1)
  (check equal? (set-count (sketches M5)) 1)
  (check equal? (set-count (sketches M5 +inf.0)) 1)
  (check equal? (set-count (sketches M5 0)) 0)
  (check equal? (set-count (sketches M5 -100)) 0)
  (check equal? (set-count (sketches M5 5)) 0)  ; κ(0 0) = 5
  (check equal? (set-count (sketches M5 6)) 1)
  (for ([S (sketches M5)])
    (check equal? (pre S) null)
    (define P (programs S))
    (check-false (term? (cost M5 P))))))

; Tests the correctness of M5.
(define (test1)
 (test-case "M5 correctness"
  (match-define (list S00) (for/list ([S (sketches M5)]) S))
  ; the solution is y=2
  (define sol (synth M5 S00))
  (check-true (sat? sol))  
  (define prog (evaluate (programs S00) sol))
  (check equal? (interpret prog '(2)) 2)  ; check that it's y=2
  (check equal? (interpret prog '(3)) 2)
  (define sol+ (synth2 M5 S00))
  (check-true (sat? sol+))  
  (define prog+ (evaluate (programs S00) sol+))
  (check equal? (interpret prog+ '(2)) 2)  ; check that it's y=2
  (check equal? (interpret prog+ '(3)) 2)))


; Tests the interface of M0.
(define (test2)
 (test-case "M0 interface"
  (check equal? (length (inputs M0)) 1)
  (check equal? (set-count (sketches M0)) 2)
  (check equal? (set-count (sketches M0 +inf.0)) 2)
  (check equal? (set-count (sketches M0 0)) 0)
  (check equal? (set-count (sketches M0 -100)) 0)
  (check equal? (set-count (sketches M0 5)) 0)  ; κ(0 0) = 5
  (check equal? (set-count (sketches M0 6)) 1)
  (check equal? (set-count (sketches M0 7)) 1)  ; κ(0 1) = 7
  (check equal? (set-count (sketches M0 8)) 2)
  (for ([S (sketches M0)])
    (check equal? (pre S) null)
    (define P (programs S))
    (check-false (term? (cost M0 P))))))

; Tests the correctness of M0.
(define (test3)
 (test-case "M0 correctness"
  (match-define (list S00 S01) (for/list ([S (sketches M0)]) S))
  ; no solution with 1 degree-0 line
  (check-true (unsat? (synth M0 S00)))
  (check-true (unsat? (synth2 M0 S00)))
  ; a solution with 1 degree-1 line: y=x
  (define sol (synth M0 S01))
  (check-true (sat? sol))  
  (define prog (evaluate (programs S01) sol))
  (check equal? (interpret prog '(2)) 2)  ; check that it's y=x
  (define sol+ (synth2 M0 S01))
  (check-true (sat? sol+))  
  (define prog+ (evaluate (programs S01) sol+))
  (check equal? (interpret prog+ '(2)) 2)  ; check that it's y=x
))

; Tests the interface of M1.
(define (test4)
 (test-case "M1 interface"
  (check equal? (length (inputs M1)) 1)
  (check equal? (set-count (sketches M1)) 6)
  (check equal? (set-count (sketches M1 +inf.0)) 6)
  (check equal? (set-count (sketches M1 0)) 0)
  (check equal? (set-count (sketches M1 -100)) 0)
  (check equal? (set-count (sketches M1 5)) 0)  ; κ(0 0) = 5
  (check equal? (set-count (sketches M1 6)) 1)
  (check equal? (set-count (sketches M1 7)) 1)  ; κ(0 1) = 7
  (check equal? (set-count (sketches M1 8)) 2)
  (check equal? (set-count (sketches M1 13)) 2)  ; κ(1 0) = 13
  (check equal? (set-count (sketches M1 14)) 3)
  (check equal? (set-count (sketches M1 17)) 3)  ; κ(0 2) = 17
  (check equal? (set-count (sketches M1 18)) 4)
  (check equal? (set-count (sketches M1 21)) 4)  ; κ(1 1) = 21
  (check equal? (set-count (sketches M1 22)) 5)
  (check equal? (set-count (sketches M1 37)) 5)  ; κ(1 2) = 37
  (check equal? (set-count (sketches M1 38)) 6)
  (for ([S (sketches M1)])
    (check equal? (pre S) null)
    (define P (programs S))
    (check-false (term? (cost M1 P))))))

; Tests the correctness of M1.
(define (test5)
 (test-case "M1 correctness"
  (for ([S (sketches M1)])
    (match (isketch-index S)
      [(list 1 2) (define sol (synth M1 S))
                  (check-true (sat? sol))
                  (define prog (evaluate (programs S) sol))
                  (check equal? (interpret prog '(4)) 16)
                  (check equal? (interpret prog '(-4)) -16)
                  (define sol+ (synth2 M1 S))
                  (check-true (sat? sol+))
                  (define prog+ (evaluate (programs S) sol+))
                  (check equal? (interpret prog+ '(4)) 16)
                  (check equal? (interpret prog+ '(-4)) -16)]
      [_          (check-true (unsat? (synth M1 S)))
                  (check-true (unsat? (synth2 M1 S)))]))))

; Tests the interface of M2.
(define (test6)
 (test-case "M2 interface"
  (check equal? (length (inputs M2)) 2)
  (check equal? (set-count (sketches M2)) 6)
  (check equal? (set-count (sketches M2 +inf.0)) 6)
  (check equal? (set-count (sketches M2 0)) 0)
  (check equal? (set-count (sketches M2 -100)) 0)
  (check equal? (set-count (sketches M2 9)) 0)  ; κ(0 0) = 9
  (check equal? (set-count (sketches M2 10)) 1)
  (check equal? (set-count (sketches M2 13)) 1)  ; κ(0 1) = 13
  (check equal? (set-count (sketches M2 14)) 2)
  (check equal? (set-count (sketches M2 21)) 2)  ; κ(1 0) = 21
  (check equal? (set-count (sketches M2 22)) 3)
  (check equal? (set-count (sketches M2 33)) 3)  ; κ(0 2) = 33
  (check equal? (set-count (sketches M2 34)) 4)
  (check equal? (set-count (sketches M2 37)) 4)  ; κ(1 1) = 37
  (check equal? (set-count (sketches M2 38)) 5)
  (check equal? (set-count (sketches M2 69)) 5)  ; κ(1 2) = 69
  (check equal? (set-count (sketches M2 70)) 6)
  (for ([S (sketches M2)])
    (check equal? (pre S) null)
    (define P (programs S))
    (check-false (term? (cost M2 P))))))

; Tests the correctness of M2.
(define (test7)
 (test-case "M2 correctness"
  (for ([S (sketches M2)])
    (match (isketch-index S)
      [(list 1 2) (define sol (synth M2 S))
                  (check-true (sat? sol))
                  (define prog (evaluate (programs S) sol))
                  (check equal? (interpret prog '(4 4)) (p2 4 4))
                  (check equal? (interpret prog '(4 -2)) (p2 4 -2))
                  (check equal? (interpret prog '(-2 4)) (p2 -2 4))
                  (check equal? (interpret prog '(-4 -4)) (p2 -4 -4))
                  (define sol+ (synth2 M2 S))
                  (check-true (sat? sol+))
                  (define prog+ (evaluate (programs S) sol+))
                  (check equal? (interpret prog+ '(4 4)) (p2 4 4))
                  (check equal? (interpret prog+ '(4 -2)) (p2 4 -2))
                  (check equal? (interpret prog+ '(-2 4)) (p2 -2 4))
                  (check equal? (interpret prog+ '(-4 -4)) (p2 -4 -4))]
      [_          (check-true (unsat? (synth M2 S)))
                  (check-true (unsat? (synth2 M2 S)))]))))

; Tests the interface of M3.
(define (test8 M3 tag)
 (test-case (format "M3 interface ~a" tag)
  (check equal? (length (inputs M3)) 2)
  (check equal? (set-count (sketches M3)) 9)
  (check equal? (set-count (sketches M3 +inf.0)) 9)
  (check equal? (set-count (sketches M3 0)) 0)
  (check equal? (set-count (sketches M3 -100)) 0)
  (check equal? (set-count (sketches M3 9)) 0)  ; κ(0 0) = 9
  (check equal? (set-count (sketches M3 10)) 1)
  (check equal? (set-count (sketches M3 13)) 1)  ; κ(0 1) = 13
  (check equal? (set-count (sketches M3 14)) 2)
  (check equal? (set-count (sketches M3 21)) 2)  ; κ(1 0) = 21
  (check equal? (set-count (sketches M3 22)) 3)
  (check equal? (set-count (sketches M3 33)) 3)  ; κ(0 2) = κ(2 0) = 33
  (check equal? (set-count (sketches M3 34)) 5)
  (check equal? (set-count (sketches M3 37)) 5)  ; κ(1 1) = 37
  (check equal? (set-count (sketches M3 38)) 6)
  (check equal? (set-count (sketches M3 61)) 6)  ; κ(2 1) = 61
  (check equal? (set-count (sketches M3 62)) 7)
  (check equal? (set-count (sketches M3 69)) 7)  ; κ(1 2) = 69
  (check equal? (set-count (sketches M3 70)) 8)
  (check equal? (set-count (sketches M3 105)) 8)  ; κ(2 2) = 105
  (check equal? (set-count (sketches M3 106)) 9)
  (for ([S (sketches M3)])
    (check equal? (pre S) null)
    (define P (programs S))
    (check-false (term? (cost M3 P))))
  (define family (sequence->list (sketches M3)))
  (check equal? (length family) 9)))

; Tests the correctness of M3.
(define (test9 M3 tag)
 (test-case (format "M3 correctness ~a" tag)
  (printf "  order: ")
  (for ([S (sketches M3)])
    (printf "~a " (isketch-index S))
    (match (isketch-index S)
      [(list 2 2) (define sol (synth M3 S))
                  (check-true (sat? sol))
                  (define prog (evaluate (programs S) sol))
                  (check equal? (interpret prog '(-6 -6)) (p3 -6 -6))
                  (check equal? (interpret prog '(-6  6)) (p3 -6  6))
                  (check equal? (interpret prog '( 6 -6)) (p3  6 -6))
                  (check equal? (interpret prog '( 6  6)) (p3  6  6))
                  (define sol+ (synth2 M3 S))
                  (check-true (sat? sol+))
                  (define prog+ (evaluate (programs S) sol+))
                  (check equal? (interpret prog+ '(-6 -6)) (p3 -6 -6))
                  (check equal? (interpret prog+ '(-6  6)) (p3 -6  6))
                  (check equal? (interpret prog+ '( 6 -6)) (p3  6 -6))
                  (check equal? (interpret prog+ '( 6  6)) (p3  6  6))]
      [_          (check-true (unsat? (synth M3 S)))
                  (check-true (unsat? (synth2 M3 S)))]))
  (printf "\n")))

; Tests the interface of M4.
(define (test10)  
 (test-case "M4 interface"
  (check equal? (length (inputs M4)) 2)
  (check equal? (set-count (sketches M4)) +inf.0)
  (check equal? (set-count (sketches M4 +inf.0)) +inf.0)
  (check equal? (set-count (sketches M4 0)) 0)
  (check equal? (set-count (sketches M4 -100)) 0)
  (check equal? (set-count (sketches M4 9)) 0)  ; κ(0 0) = 9
  (check equal? (set-count (sketches M4 10)) 1)))

; Tests the correctness of M4.
(define (test11)
 (test-case "M4 correctness"
  (define best-cost +inf.0)
  (define-values (more-sketches? next-sketch)
    (sequence-generate (sketches M4 best-cost)))
  (define done (make-hash))
  (let loop ([n 50])
    (when (= n 0) (error "maximum depth for M4 exceeded"))
    (when (more-sketches?)
      (define S (next-sketch))
      (cond [(hash-has-key? done S) (loop n)]
            [else (define sol (synth M4 S))
                  (hash-set! done S (sat? sol))
                  (match (isketch-index S)
                    [(list 2 2) (check-true (sat? sol))
                                (define P (evaluate (programs S) sol))
                                (set! best-cost (cost M4 P))
                                (set!-values (more-sketches? next-sketch)
                                             (sequence-generate (sketches M4 best-cost)))]
                    [_          (check-true (unsat? sol))])
                  (loop (- n 1))])))
  (check-false (infinite? best-cost))))
  

(define/provide-test-suite piecewise-tests
  (test0)
  (test1)
  (test2)
  (test3)
  (test4)
  (test5)
  (test6)
  (test7)
  (test8 M3 'default)
  (test9 M3 'default)
  (test10)
  (test11)
  (test8 M6 'sum)
  (test9 M6 'sum)
  )

(run-tests-quiet piecewise-tests)
