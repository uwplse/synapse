#lang s-exp rosette

(require "../../opsyn/engine/metasketch.rkt"
         "../../opsyn/metasketches/superoptimization.rkt"
         "../../opsyn/metasketches/cost.rkt"
         "../../opsyn/bv/lang.rkt")

(provide example example2 example3 example4)

; Postcondition for the `max` function: the outout of program P applied to the
; given symbolic inputs should be the max of those inputs
(define (max-post P inputs)
  (match-define (list x y) inputs)
  (define out (interpret P inputs))
  (assert (>= out x))
  (assert (>= out y))
  (assert (or (= out x) (= out y))))

; Simplest example metasketch for `max`: generate a program that uses only < and
; if-then-else expressions and that satisfies the postcondition. The optimal
; solution is the program `if (x < y) then y else x`.
(define (example)
  (superopt∑ #:arity 2
             #:instructions (list bvslt ite)
             #:post max-post
             #:cost-model constant-cost-model))

; An example metasketch that is not allowed to use if-then-else expressions, and
; so must perform bit-manipulation instead.
(define (example2)
  (superopt∑ #:arity 2
             #:instructions (list bvand bvor bvxor bvnot bvneg bvadd bvsub bvslt)
             #:post max-post
             #:cost-model constant-cost-model))

; An example metasketch that is allowed to use both if-then-else expressiona and
; the bitwise manipulations above. The cost model makes if-then-else expressions
; expensive, and so the optimal solution is the same as `example2`, despite that
; program being longer.
(define c (static-cost-model (hash-set sample-costs ite 8)))
(define (example3)
  (superopt∑ #:arity 2
             #:instructions (list bvand bvor bvxor bvnot bvneg bvadd bvsub bvslt ite)
             #:post max-post
             #:cost-model c))

; An example demonstrating preconditions: if the function always requires that
; x < y, then max is trivial to implement.
(define (max-pre inputs)
  (match-define (list x y) inputs)
  (assert (< x y)))
(define (example4)
  (superopt∑ #:arity 2
             #:instructions (list bvor)
             #:pre max-pre
             #:post max-post
             #:cost-model constant-cost-model))