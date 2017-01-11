#lang s-exp rosette

(require "lang.rkt" rosette/lib/angelic)

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
           ;; The first time you call (equal? bv bvsub), it returns
           ;; true for some reason. This also holds for other
           ;; instructions like bvadd. Every subsequent time it
           ;; behaves the way you would expect. As a result, if you
           ;; comment out the line below, everything breaks.
           ;; The command 'racket benchmarks/run.rkt "(hd-d0 1)"' will
           ;; work if the line below is present, but fails if you
           ;; comment it out.
           (equal? bv constructor)
           (cond [(bv? constructor) constructor] ; baked-in constant
                 [(equal? bv constructor)
                  (local [(define-symbolic* val (bitvector (current-bitwidth)))] 
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
