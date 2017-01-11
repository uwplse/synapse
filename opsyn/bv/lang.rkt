#lang s-exp rosette

(require "../engine/util.rkt" rosette/lib/match racket/serialize)

(require (only-in rosette [bv rosette-bv]
                  [bveq rosette-bveq] [bvslt rosette-bvslt]
                  [bvsgt rosette-bvsgt] [bvsle rosette-bvsle]
                  [bvsge rosette-bvsge] [bvult rosette-bvult]
                  [bvugt rosette-bvugt] [bvule rosette-bvule]
                  [bvuge rosette-bvuge] [bvnot rosette-bvnot]
                  [bvor rosette-bvor] [bvand rosette-bvand]
                  [bvxor rosette-bvxor] [bvshl rosette-bvshl]
                  [bvlshr rosette-bvlshr] [bvashr rosette-bvashr]
                  [bvneg rosette-bvneg] [bvadd rosette-bvadd]
                  [bvsub rosette-bvsub] [bvmul rosette-bvmul]
                  [bvudiv rosette-bvudiv] [bvsdiv rosette-bvsdiv]
                  [bvurem rosette-bvurem] [bvsrem rosette-bvsrem]
                  [bvsmod rosette-bvsmod]))

(provide (except-out (all-defined-out) define-instruction bool->bv bvcmp bv=0? bv=1? bviszero maybe-int->bv))

; ------------ instructions ------------ ;

(struct instruction () #:transparent)
(struct unary instruction   (r1) #:transparent)         ; unary instruction
(struct binary instruction  (r1 r2) #:transparent)     ; binary instruction
(struct ternary instruction (r1 r2 r3) #:transparent) ; ternary instruction

; Creates instruction types with the given ids and arity (unary, binary, or ternary).
; Also define serialize and de-serialize info for the instruction.
(define-syntax (define-instruction stx)
  (syntax-case stx ()
    [(_ [id kind])
     (with-syntax ([deserialize-id (datum->syntax #'id
                                                  (string->symbol
                                                   (format "deserialize-info:~a" (syntax-e #'id)))
                                                  #'id)])
       #'(begin
           (define deserialize-id
             (make-deserialize-info
              (lambda e (apply id e))
              (const #f)))
           (struct id kind () #:transparent
             #:property prop:serializable
             (make-serialize-info
              (lambda (s)
                (match s
                  [(unary r1) (vector r1)]
                  [(binary r1 r2) (vector r1 r2)]
                  [(ternary r1 r2 r3) (vector r1 r2 r3)]))
              #'deserialize-id
              #f
              (or (current-load-relative-directory) (current-directory))))))]
    [(_ [id kind] more ...)
     #'(begin
         (define-instruction [id kind])
         (define-instruction more ...))]))

(define-instruction 
  ; ------------ theory of bitvectors ------------ ;
  [bv unary]                                                 ; bitvector constant
  [bvnot unary] [bvand binary] [bvor binary] [bvxor binary]  ; bitwise operations
  [bvshl binary] [bvlshr binary] [bvashr binary]             ; bitwise shifts: left and (un)signed right 
  [bvneg unary] [bvadd binary] [bvsub binary] [bvmul binary] ; arithmetic operators
  [bvsdiv binary] [bvudiv binary] 
  [bvsrem binary] [bvurem binary]
  [bveq binary] [bvredor unary]                              ; comparisons
  [bvsle binary] [bvslt binary] [bvule binary] [bvult binary] 
  
  [ite ternary]                                              ; if-then-else
  ; ------------ additional instructions ------------ ;
  [bvabs unary] [bvsqrt unary] [bvmax binary] [bvmin binary] 
  
  ; ------------ additional ICFP instructions ------------ ;
  [shr1 unary] [shr4 unary] [shr16 unary] [shl1 unary] [if0 ternary]
)  

; Returns true iff the given instruction is an instance of a 
; commutative instruction type.
(define (commutative? inst)
  (or (bvadd? inst) (bvmul? inst) 
      (bvand? inst) (bvor? inst) (bvxor? inst)
      (bvmin? inst) (bvmax? inst) (bveq? inst)))

; ------------ shorthands for instruction accessors ------------ ;
(define (r1 v)
  (match v
    [(unary f) f]
    [(binary f _) f]
    [(ternary f _ _) f]))

(define (r2 v)
  (match v
    [(binary _ f) f]
    [(ternary _ f _) f]))

(define r3 ternary-r3)

; Returns true iff the given register is 
; read by any of the given instructions.
(define (used? reg insts)
  (ormap
   (lambda (inst)
     (match inst
       [(unary r1) (= r1 reg)]
       [(binary r1 r2) (or (= r1 reg) (= r2 reg))]
       [(ternary r1 r2 r3) (or (= r1 reg) (= r2 reg) (= r3 reg))]))
   insts))

; ------------ programs ------------ ;  

; A program with n instructions serializes to a vector of length n+1:
; the first element is the number of inputs, and the remaining are the
; serializations of each instruction
(define deserialize-info:program
  (make-deserialize-info
   (lambda e
     (program (first e) (for/list ([op (rest e)])
                          (deserialize op))))
   (const #f)))
; A program takes a given number of inputs, and its body 
; is a list of instructions.
(struct program (inputs instructions)
  #:transparent
  #:property prop:serializable
  (make-serialize-info
   (lambda (s)
     (vector-append
      (vector (program-inputs s))
      (for/vector ([op (program-instructions s)])
        (serialize op))))
   #'deserialize-info:program
   #f
   (or (current-load-relative-directory) (current-directory))))

; ------------ semantics ------------ ;  

(define (maybe-int->bv x)
  (if (integer? x)
      (integer->bitvector x (bitvector (current-bitwidth)))
      x))

; Interprets the given program on the given list of inputs.
(define (interpret prog inputs)
  (unless (= (program-inputs prog) (length inputs))
    (error 'interpret "expected ~a inputs, given ~a" (program-inputs prog) inputs))
  (parameterize ([current-bitwidth (match (car inputs)
                                     [(rosette-bv _ (bitvector bw)) bw]
                                     [(term _ (bitvector bw)) bw])])
    (define insts (program-instructions prog))
    (define size (+ (length inputs) (length insts)))
    (define reg (make-vector size))
    (define (store i v) (vector-set! reg i (finitize v)))
    (define (load i)
      (vector-ref reg i))
    (for ([(in i) (in-indexed inputs)])
      (store i in))
    (for ([inst insts] [idx (in-range (length inputs) (vector-length reg))])
      (match inst
        [(bv val)       (store idx (maybe-int->bv val))]
        [(bvnot r1)     (store idx (rosette-bvnot (load r1)))]
        [(bvand r1 r2)  (store idx (rosette-bvand (load r1) (load r2)))]
        [(bvor r1 r2)   (store idx (rosette-bvor (load r1) (load r2)))]
        [(bvxor r1 r2)  (store idx (rosette-bvxor (load r1) (load r2)))]
        [(bvshl r1 r2)  (store idx (rosette-bvshl (load r1) (load r2)))]
        [(bvlshr r1 r2) (store idx (rosette-bvlshr (load r1) (load r2)))]
        [(bvashr r1 r2) (store idx (rosette-bvashr (load r1) (load r2)))]
        [(bvneg r1)     (store idx (rosette-bvneg (load r1)))]
        [(bvadd r1 r2)  (store idx (rosette-bvadd (load r1) (load r2)))]
        [(bvsub r1 r2)  (store idx (rosette-bvsub (load r1) (load r2)))]
        [(bvmul r1 r2)  (store idx (rosette-bvmul (load r1) (load r2)))]
        [(bvsdiv r1 r2) (store idx (rosette-bvsdiv (load r1) (load r2)))]
        [(bvudiv r1 r2) (store idx (rosette-bvudiv (load r1) (load r2)))]
        [(bvsrem r1 r2) (store idx (rosette-bvsrem (load r1) (load r2)))]
        [(bvurem r1 r2) (store idx (rosette-bvurem (load r1) (load r2)))]
        [(bveq r1 r2)   (store idx (bvcmp rosette-bveq (load r1) (load r2)))]
        [(bvredor r1)   (store idx (rosette-bvnot (bviszero (load r1))))]
        [(bvsle r1 r2)  (store idx (bvcmp rosette-bvsle (load r1) (load r2)))]
        [(bvslt r1 r2)  (store idx (bvcmp rosette-bvslt (load r1) (load r2)))]
        [(bvule r1 r2)  (store idx (bvcmp rosette-bvule (load r1) (load r2)))]
        [(bvult r1 r2)  (store idx (bvcmp rosette-bvult (load r1) (load r2)))]
        ;[(bvabs r1)     (store idx (abs (load r1)))]
        ;[(bvsqrt r1)    (store idx (sqrt (load r1)))]
        ;[(bvmin r1 r2)  (store idx (min (load r1) (load r2)))]
        ;[(bvmax r1 r2)  (store idx (max (load r1) (load r2)))]
        [(ite r1 r2 r3) (store idx (if (bv=0? (load r1)) (load r3) (load r2)))]
        [(shr1 r1)      (store idx (rosette-bvlshr (load r1) 1))]
        [(shr4 r1)      (store idx (rosette-bvlshr (load r1) 4))]
        [(shr16 r1)     (store idx (rosette-bvlshr (load r1) 16))]
        [(shl1 r1)      (store idx (rosette-bvshl (load r1) 1))]
        [(if0 r1 r2 r3) (store idx (if (bv=1? (load r1)) (load r2) (load r3)))]
        [_ (error (format "Unknown instruction ~a" inst))]
        ))
    (load (- size 1))))

(define (bool->bv v) 
  (integer->bitvector (if v 1 0) (bitvector (current-bitwidth))))

(define (bvcmp pred x y)
  (bool->bv (pred x y)))

(define (bv=0? v)
  (rosette-bveq v (rosette-bv 0 (current-bitwidth))))

(define (bv=1? v)
  (rosette-bveq v (rosette-bv 1 (current-bitwidth))))

(define (bviszero v)
  (bool->bv (bv=0? v)))
