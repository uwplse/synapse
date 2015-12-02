#lang racket

(require "util.rkt"
         (only-in rosette || ! current-bitwidth)
         rosette/solver/solver
         rosette/solver/solution
         rosette/solver/kodkod/kodkod
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
        [(ormap false? post) (empty-solution)]      ; any binding of xs to values causes post violation
        [else
         (define ¬post (apply || (map ! post)))
         (parameterize ([current-custodian (make-custodian)])
           (∃solve kodkod% pre ¬post)
           (∃solve z3% pre ¬post)
           (begin0 
             (thread-receive)
             (custodian-shutdown-all (current-custodian))))]))

(define (∃solve solver% pre ¬post)
  (define parent (current-thread))
  (thread
   (thunk
    (define solver (new solver%))
    (send/apply solver assert pre)
    (send solver assert ¬post)
    (thread-send parent (send/handle-breaks solver solve)))))

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
      (cond [(and (empty? pre) (empty? post)) (unsat)]  ; #t => #t
            [(ormap false? pre) (unsat)]                ; any binding of xs to values causes pre violation
            [(ormap false? post) (empty-solution)]      ; any binding of xs to values causes post violation
            [else
             (define ¬post (apply || (map ! post)))
             (parameterize ([current-custodian (make-custodian)])
               (∃solve kodkod% pre ¬post)
               (∃solve z3% pre ¬post)
               (begin0
                 (thread-receive)
                 (custodian-shutdown-all (current-custodian))))]))
    (thread-send output (list (current-thread) result)))))
  