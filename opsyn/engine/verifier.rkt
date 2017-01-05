#lang racket

(require "util.rkt"
         (only-in rosette || ! current-bitwidth)
         rosette/solver/solver
         rosette/solver/solution
         rosette/solver/smt/z3)

(provide verify verify-async)

; Checks the validity of the formula Pre => Post, where 
; * Pre and Post stand for conjunctions of boolean values in the lists 
;   pre and post, respectively.
; If the formula is valid, returns (unsat).  Otherwise returns a model for xs 
; that violates the formula.  This procedure may run several solvers in parallel.
(define (verify #:pre [pre '()] #:post [post '()])
  (cond [(and (empty? pre) (empty? post)) (unsat)]  ; #t => #t
        [(ormap false? pre) (unsat)]                ; any binding of xs to values causes pre violation
        [else
         (define ¬post (apply || (map ! post)))
         (∃solve (z3) pre ¬post)]))

(define (∃solve solver pre ¬post)
  (solver-assert solver pre)
  (solver-assert solver (list ¬post))
  (solver-check solver)
  #;(send/handle-breaks solver solve))

; Checks the validity of the formula Pre ⇒ Post, as with verify above.
; This procedure runs asynchronously, immediately returning a thread that
; runs the verification. When complete, that thread will send a message to
; the specified output thread containing the result of the verification.
; The verification may run several solvers in parallel.
(define (verify-async #:pre [pre '()] 
                      #:post [post '()] 
                      #:output [output (current-thread)])
  (thread
   (thunk
    (define result
      (verify #:pre pre #:post post))
    (thread-send output (list (current-thread) result)))))
  
