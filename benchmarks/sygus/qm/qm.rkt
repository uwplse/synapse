#lang s-exp rosette

(require racket/generator racket/serialize rosette/lib/angelic rosette/base/core/polymorphic
         "../../../opsyn/engine/eval.rkt"
         "../../../opsyn/engine/metasketch.rkt"
         "../../../opsyn/metasketches/imetasketch.rkt"
         "../../../opsyn/metasketches/order.rkt")

(provide qm-ms qm-output deserialize-info:qm-program)

; Returns a metasketch for a given SyGuS QM problem.
; The cost model for this metasketch is simply the 
; maximum depth of the expression tree.
(define (qm-ms arity prog #:order [order #f])
  (define consts '(0 1 3))
  (define M 
    (imeta
     #:arity arity
     #:pre void 
     #:post prog
     #:structure void
     #:subset (qm-subset order)
     #:ref 
     (match-lambda 
       [(list i) 
        (qm-program 
         (inputs M) 
         (grammar (append (inputs M) consts) i) 
         i)])
     #:cost (lambda (P xs) (qm-program-depth P))
     #:minbw (const 6)))
  M)

(define (qm-output P xs)
  (evaluate (qm-program-expr P)
            (sat (for/hash ([i (qm-program-inputs P)][x xs]) 
                   (values i x)))))

(define-namespace-anchor a)
(define ns (namespace-anchor->namespace a))
; an qm-program serializes to a vector of length 3:
; 0: a list of the same length as qm-program-inputs, where
;    each element is a symbol corresponding to an input variable name
; 1: a string representation of qm-program-expr
; 2: the qm-program-depth
(define deserialize-info:qm-program
  (make-deserialize-info
    (lambda e
      (parameterize ([current-oracle (oracle)])
        (define inputs
          (for/list ([x (first e)])
            (define-symbolic* in integer?)
            (namespace-set-variable-value! x in #f ns)
            in))
        (qm-program
          inputs
          (eval (second e) ns)
          (third e))))
    (const #f)))
(struct qm-program (inputs expr depth)
  #:transparent
  #:property prop:serializable
  (make-serialize-info
   (lambda (s)
     (vector
      (for/list ([x (qm-program-inputs s)]) (term->datum x))
      (term->datum (qm-program-expr s))
      (qm-program-depth s)))
   #'deserialize-info:qm-program
   #f
   (or (current-load-relative-directory) (current-directory))))


; Grammar with unwinding control.
(define (grammar terminals ibnd)
  (define (qm a b)
    (if (< a 0) b a))
  
  (define (int bnd)
    (if (<= bnd 0)
        (apply choose* terminals)
        (begin
          (define e0 (int (- bnd 1)))
          (define e1 (int (- bnd 1)))
          (choose* (qm e0 e1) (+ e0 e1) (- e0 e1)))))
  
  (int ibnd))

(define (qm-subset order)
  (lambda (c)
    (if (false? order)
        (space c)
        (ordered-space (space c) (order (list c))))))

(struct space (c) 
  #:transparent
  #:guard (lambda (c name) (max c 0))
  #:property prop:sequence
  (lambda (self) (in-set self))
  #:methods gen:set
  [(define (set-count self)
     (space-c self))
   
   (define (set-member? self idx)
     (match-define (list i) idx)
     (< i (space-c self)))
   
   (define (in-set self)
     (in-generator
      (match self 
        [(space c)
         (for ([i (in-range 0 c)]) (yield (list i)))])))])
