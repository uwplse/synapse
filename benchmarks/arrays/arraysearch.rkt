#lang s-exp rosette

(require racket/generator racket/serialize rosette/lib/tools/angelic rosette/base/generic
         "../../opsyn/engine/eval.rkt"
         "../../opsyn/engine/metasketch.rkt"
         "../../opsyn/metasketches/imetasketch.rkt"
         "../../opsyn/metasketches/order.rkt")

(provide array-search deserialize-info:array-program)

; Returns a metasketch for a SyGuS array search problem of 
; size n. The cost model for this metasketch is simply the 
; maximum depth of the expression tree.
(define (array-search n #:order [order #f])
  (unless (>= n 2)
    (raise-arguments-error 'array-search "expected n ≥ 2" "n" n))
  (define arity (+ n 1))
  (define consts (build-list arity values))
  (define M 
    (imeta
     #:arity arity
     #:pre array-search-pre 
     #:post array-search-post
     #:structure void
     #:subset (array-search-subset order)
     #:ref 
     (match-lambda 
       [(list i b) 
        (array-program 
         (inputs M) 
         (grammar (append (inputs M) consts) i b) 
         i)])
     #:cost (lambda (P xs) (array-program-depth P))
     #:minbw (const (integer-length arity))))
  M)

(define (array-search-pre xs)
  (for ([x (cdr xs)] [y (cddr xs)])
    (assert (< x y))))

(define (array-search-post P xs)
  (define out 
    (evaluate (array-program-expr P)
              (sat (for/hash ([i (array-program-inputs P)][x xs]) 
                     (values i x)))))
  (match xs
    [(list k y1 _ ... yn)
     (assert (=> (< k y1) (= out 0)))
     (assert (=> (> k yn) (= out (sub1 (length xs)))))
     (for ([x (cdr xs)][y (cddr xs)][i (in-naturals 1)])
       (assert (=> (and (> k x) (< k y)) (= out i))))]))

(define-namespace-anchor a)
(define ns (namespace-anchor->namespace a))
; an array-program serializes to a vector of length 3:
; 0: a list of the same length as array-program-inputs, where
;    each element is a symbol corresponding to an input variable name
; 1: a string representation of array-program-expr
; 2: the array-program-depth
(define deserialize-info:array-program
  (make-deserialize-info
    (lambda e
      (parameterize ([current-oracle (oracle)])
        (define inputs
          (for/list ([x (first e)])
            (define-symbolic* in number?)
            (namespace-set-variable-value! x in #f ns)
            in))
        (array-program
          inputs
          (eval (second e) ns)
          (third e))))
    (const #f)))
(struct array-program (inputs expr depth)
  #:transparent
  #:property prop:serializable
  (make-serialize-info
   (lambda (s)
     (vector
      (for/list ([x (array-program-inputs s)]) (term->datum x))
      (term->datum (array-program-expr s))
      (array-program-depth s)))
   #'deserialize-info:array-program
   #f
   (or (current-load-relative-directory) (current-directory))))


; Grammar with separate unwinding control for int and bool 
; subexpressions.  Note that the output is an int expression 
; so the bool expression will never be unwound more than 
; min(ibnd-1, bbnd).
(define (grammar terminals ibnd bbnd)
  
  (define (bool bnd)
    (define e0 (int (min (- bnd 1) ibnd)))
    (define e1 (int (min (- bnd 1) ibnd)))
    (choose* (< e0 e1) (<= e0 e1) (> e0 e1) (>= e0 e1)))

  (define (int bnd)
    (if (<= bnd 0)
        (apply choose* terminals)
        (if (bool (min (- bnd 1) bbnd)) 
            (int (- bnd 1)) 
            (int (- bnd 1)))))
  
  (int ibnd))

(define (array-search-subset order)
  (lambda (c)
    (if (false? order)
        (space c)
        (ordered-space (space c) (order (list c (sub1 c)))))))

(struct space (c) 
  #:transparent
  #:guard (lambda (c name) (max c 0))
  #:property prop:sequence
  (lambda (self) (in-set self))
  #:methods gen:set
  [(define (set-count self) 
     (match self
       [(space 0) 0]
       [(space c) (+ 1 (/ (* (- c 1) c) 2))]))
   
   (define (set-member? self idx)
     (match-define (list i b) idx)
     (and
      (< i (space-c self))
      (or (and (= i 0) (= b 0))
          (< b i))))
   
   (define (in-set self)
     (in-generator
      (match self 
        [(space c)
         (when (> c 0)
           (yield '(0 0)))
         (for*([i (in-range 0 c)][b i]) 
           (yield (list i b)))])))])
  
  

