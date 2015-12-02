#lang s-exp rosette

(require "lang.rkt" rosette/lib/reflect/match rosette/lib/tools/angelic)

(provide ??instruction ??program break-commutativity-symmetries)

; Creates a symbolic instruction that is drawn from the given 
; list of instruction types and that may read any of the registers 
; in the given inputs list.   
(define (??instruction insts [inputs '(#f)])
  (define r1 (apply choose* inputs))
  (define r2 (apply choose* inputs))
  (define r3 (apply choose* inputs))
  (apply choose* 
         (for/list ([constructor insts])
           (cond [(bv? constructor) constructor] ; baked-in constant
                 [(equal? bv constructor)           
                  (local [(define-symbolic* val number?)] 
                    (bv val))]
                 [(= 1 (procedure-arity constructor)) (constructor r1)]
                 [(= 2 (procedure-arity constructor)) (constructor r1 r2)]
                 [else (constructor r1 r2 r3)]))))

; Creates a symbolic program with n inputs and k lines 
; of code that can contain any of the given instruction types.
(define (??program n k insts)
  (program
   n
   (for/list ([output (in-range n (+ n k))])
     (??instruction insts (build-list output identity)))))

; Emits assertions that constrain all commutative binary instructions 
; in p to read the lower-index register before reading the higher-index
; register.
(define (break-commutativity-symmetries p)
  (for ([inst (program-instructions p)])
    (when (commutative? inst)
      (assert (<= (r1 inst) (r2 inst))))))
