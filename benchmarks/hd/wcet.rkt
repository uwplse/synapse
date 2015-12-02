#lang s-exp rosette

(require rosette/lib/tools/angelic rosette/lib/reflect/match 
         racket/generator racket/serialize 
         rosette/solver/kodkod/kodkod
         (only-in racket [member member*]))

(require "../../opsyn/bv/lang.rkt"   
         "../../opsyn/engine/metasketch.rkt" 
         "../../opsyn/engine/eval.rkt"
         "../../opsyn/engine/util.rkt"
         "../../opsyn/metasketches/imetasketch.rkt" 
         "../../opsyn/metasketches/cost.rkt")

(provide hd-sgn deserialize-info:wcet-expr)


; Returns a grammar-based metasketch for the 
; HD sgn benchmark, using the given cost model. 
(define (hd-sgn #:dynamic-cost? [dynamic-cost? #t])
  (define consts '(-1 0 1 31))
  (define M 
    (imeta
     #:arity 1
     #:ref (lambda (idx) (expr (hd-sgn-grammar (append (inputs M) consts) (car idx))
                               (inputs M)
                               (car idx)))
     #:pre void
     #:post hd-sgn-post
     #:structure void
     #:cost  (if dynamic-cost? hd-sgn-wt hd-sgn-ast) ; (const 1) ; also breaks
     #:minbw (const 32)
     #:subset (lambda (c) (space 5));hd-sgn-gradient
     ))
  M)

(define (hd-sgn-post E xs)
  (define out 
    (evaluate (interpret* (expr-body E))
              (sat (for/hash ([i (expr-inputs E)][x xs]) 
                     (values i x)))))
  (assert (= out (sgn (car xs)))))

(define (hd-sgn-wt E xs)
  (define κ (box 0))
  (interpret* (expr-body E)  κ)
  (define wt
    (evaluate 
     (unbox κ) 
     (sat (for/hash ([i (expr-inputs E)][x xs]) 
            (values i x)))))
  (define wt-sym (symbolics wt))
  (cond [(and (not (null? wt-sym))     ; κ evaluated on a concrete program and 
              (for/and ([sym wt-sym])  ; produced an input-dependent term.
                (member* sym xs)))     ; need to maximize that term to get WCET.
         (define solver (new kodkod-incremental%))
         (define wcet 
           (let loop ([current-wcet 0])
             (send solver assert (> wt current-wcet))
             (define sol (send solver solve))
             (if (sat? sol)
                 (loop 
                  (evaluate 
                   wt 
                   (sat (for/hash ([sym wt-sym]) ; pad solution if needed
                          (values sym (if (constant? (sol sym)) 0 (sol sym)))))))
                 current-wcet)))           
         (send solver shutdown)
         wcet]
        [else                          ; κ evaluated on a sketch and/or 
         wt]))                         ; produced a concrete value.




(define (hd-sgn-gradient [c +inf.0]) (space c))
  

(define-namespace-anchor a)
(define ns (namespace-anchor->namespace a))
; an expr serializes to a vector of length 3:
; 0: a string representation of expr-body
; 1: a list of the same length as expr-inputs, where
;    each element is a symbol corresponding to an input variable name
; 2: the expr-depth
(define deserialize-info:wcet-expr
  (make-deserialize-info
    (lambda e
      (parameterize ([current-oracle (oracle)])
        (define inputs
          (for/list ([x (second e)])
            (define-symbolic* in number?)
            (namespace-set-variable-value! x in #f ns)
            in))
        (expr
          (eval (call-with-input-string (first e) read) ns)
          inputs
          (third e))))
    (const #f)))

(struct expr (body inputs depth)
  #:transparent
  #:property prop:serializable
  (make-serialize-info
   (lambda (s)
     (vector
      (parameterize ([error-print-width 100000])
        (format "~v" (expr-body s)))
      (for/list ([x (expr-inputs s)]) (term->datum x))
      (expr-depth s)))
   #'deserialize-info:wcet-expr
   #f
   (or (current-load-relative-directory) (current-directory))))

(define (hd-sgn-grammar terminals depth)
  (if (<= depth 0)
      (apply choose* terminals)
      (let ([left (hd-sgn-grammar terminals (- depth 1))]
            [right (hd-sgn-grammar terminals (- depth 1))])
        (apply choose*
         (bvor left right)
         (bvneg left)
         (bvashr left right)
         (bvlshr left right)
         (ite ((choose* bvslt bveq) (apply choose* terminals) (apply choose* terminals)) 
              left right)
         terminals))))

(define (interpret* E [cost (box 0)])
  (match E
    [(bvashr left right)
     (set-box! cost (+ 1 (unbox cost)))
     (finitize (>> (interpret* left cost) (interpret* right cost)))]
    [(bvlshr left right)
     (set-box! cost (+ 1 (unbox cost)))
     (finitize (>>> (interpret* left cost) (interpret* right cost)))]
    [(bvor left right)
     (set-box! cost (+ 1 (unbox cost)))
     (finitize (bitwise-ior (interpret* left cost) (interpret* right cost)))]
    [(bvneg left)
     (set-box! cost (+ 1 (unbox cost)))
     (finitize (- (interpret* left cost)))]
    [(ite test then else)
     (set-box! cost (+ 2 (unbox cost)))
     (if (interpret* test cost) (interpret* then cost) (interpret* else cost))]
    [(bvslt left right)
     (set-box! cost (+ 1 (unbox cost)))
     (< (interpret* left cost) (interpret* right cost))]
    [(bveq left right)
     (set-box! cost (+ 1 (unbox cost)))
     (= (interpret* left cost) (interpret* right cost))]
    [c (set-box! cost (+ 1 (unbox cost)))
       (finitize c)]))


(define (hd-sgn-ast E xs)
  (let cost ([E (expr-body E)])
    (match E
      [(bvashr left right)
       (+ 1 (cost left) (cost right))]
      [(bvlshr left right)
       (+ 1 (cost left) (cost right))]
      [(bvor left right)
       (+ 1 (cost left) (cost right))]
      [(bvneg left)
       (+ 1 (cost left))]
      [(ite test then else)
       (+ 2 (cost test) (cost then) (cost else))]
      [(bvslt left right)
       (+ 1 (cost left) (cost right))]
      [(bveq left right)
       (+ 1 (cost left) (cost right))]
      [c 1])))

(struct space (c)
  #:transparent
  #:guard (lambda (c name) (max c 0))
  #:property prop:sequence
  (lambda (self) (in-set self))
  #:methods gen:set
  [(define (set-count self) (space-c self))
   
   (define (set-member? self idx)
     (< (car idx) (space-c self)))
   
   (define (in-set self) 
     (in-generator
      (for ([idx (in-range 0 (space-c self))])
        (yield (list idx)))))])
    
  
(define (reference x)
  (bvor
   (bvashr x 31)
   (bvlshr
    (bvneg x)
    31)))

(define (desired x)
  (ite (bvslt x 0)
       -1
       (ite (bveq x 0)
            0
            1)))

(define (synth x)
  (ite (bvslt x 0)
       (bvashr 
        (ite (bvslt x 31) x 31)
        (ite (bvslt x 0) 31 0))
       (bvlshr
        (bvneg x)
        (bvor 0 31))))


;(define-symbolic x number?)
;(define r (expr (reference x) (list x) 5))
;(define d (expr (desired x) (list x) 5))
;(define s (expr (synth x) (list x) 5))
