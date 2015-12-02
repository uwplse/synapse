#lang s-exp rosette

(require "../../opsyn/engine/util.rkt")

(provide (all-defined-out))

; Utility procedures for defining pre conditions 
; on inputs and (relaxed) correctness constraints 
; on outputs.

; Returns a procedure that takes as input a list of 
; numbers and asserts that all of them are between 
; low and high, inclusive.
(define (range low high)
  (procedure-rename
   (lambda (xs)
    (for ([x xs])
      (let ([x (finitize x)])
        (assert (<= (finitize low) x))
        (assert (<= x (finitize high))))))
   'range))

; Asserts the correctness constraint p = s.
(define (exact p s)
  (assert (= (finitize p) (finitize s))))

; Returns a procedure that asserts a relaxed 
; correctness constraint on p and s, which constrains p 
; to be p within |s| >> e of s.
(define (relaxed e)
  (if (= e 32)
      exact
      (procedure-rename
       (lambda (p s)
         (let* ([s (finitize s)]
                [p (finitize p)]
                [e (finitize e)]
                [diff (finitize (abs (finitize (- s p))))])
           (assert (>= diff 0))
           (assert (<= diff (finitize (>> (finitize (abs s)) e))))))
       'relaxed)))
