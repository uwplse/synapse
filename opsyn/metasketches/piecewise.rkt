#lang s-exp rosette

(require "imetasketch.rkt" "cost.rkt" "iterator.rkt" "order.rkt"
         "../bv/lang.rkt"
         racket/generator racket/serialize)

(provide piecewise piecewise/cost deserialize-info:piecewise-program
         piecewise-program-coefficients)

; This procedure constructs a piecewise function metasketch
; that represents a family of piecewise polynomial approximation sketches.
; Each sketch in the family is a piecewise polynomial approximation
; with a fixed number of pieces and a fixed degree for each piece.
;
; The procedure constructs a metasketch M from the following inputs:
;
; * maxpieces : (or/c natural/c +inf.0) is the (inclusive) maximum number of pieces
;   to include in a polynomial approximation.
;
; * maxdegree: (or/c natural/c +inf.0) is the (inclusive) maximum degree of each
;   polynomial in the approximation.
;
; * arity : natural/c is the input arity of the polynomial.
;
; * pre : (listof number?) -> void? emits assertions on (symbolic)
;   inputs that represent preconditions for all programs in M.
;
; * post : program? -> (listof number?) -> void? emits assertions that
;   constrain the output of all programs in M when applied to
;   (symbolic) inputs
;
; * cost-model : (or/c procedure? instruction?) -> natural-number/c
;   is a function that maps each instruction constructor or instance in BV
;   to a natural number representing its cost. The cost model must be additive
;   in the following senses:
;     1. κ(bv) + κ(bvslt) + κ(ite) > 0
;     2. κ(bvmul) + κ(bv) + κ(bvadd) > 0
;   Because it will be used for iteration, the cost model cannot be symbolic.
;
; * order : (or/c #f ((listof number?) . -> . sequence?)) is a procedure
;   that, given the bounds of an index space, produces a sequence that is a
;   search order for that space. If #f, a default search order is used.
(define (piecewise #:maxpieces [maxpieces +inf.0]
                   #:maxdegree [maxdegree +inf.0]
                   #:arity arity
                   #:pre [pre void]
                   #:post [post void]
                   #:cost-model [cost-model sample-cost-model]
                   #:order [order #f])
  (imeta
   #:arity arity
   #:pre pre
   #:post (piecewise-post post)
   #:structure piecewise-structure
   #:cost (∑cost cost-model)
   #:ref (curry piecewise-ref arity)
   #:subset (piecewise-subset arity maxpieces (+ maxdegree 1) (∑cost cost-model) order)
   #:minbw piecewise-minbw))

; Constructs a piecewise function metasketch as above, except the cost function
; is arbitrary.
(define (piecewise/cost #:maxpieces [maxpieces +inf.0]
                        #:maxdegree [maxdegree +inf.0]
                        #:arity arity
                        #:pre [pre void]
                        #:post [post void]
                        #:cost cost
                        #:order [order #f])
  (unless (and (natural-number/c maxpieces) (natural-number/c maxdegree))
    (error "need non-infinite bounds for arbitrary-cost piecewise"))
  (imeta
   #:arity arity
   #:pre pre
   #:post (piecewise-post post)
   #:structure piecewise-structure
   #:cost cost
   #:ref (curry piecewise-ref arity)
   #:subset (piecewise-subset-no-cost arity maxpieces (+ maxdegree 1) order)
   #:minbw piecewise-minbw))


(define (piecewise-minbw S)
  (+ 1 (integer-length (apply max (isketch-index S)))))

; A piecewise program with n instructions serializes to a vector of length n+5:
; 0. number of inputs
; 1. number of pieces
; 2. degree of each piece
; 3. coefficients
; 4. boundary conditions
; 5 to n+5. instructions
(define deserialize-info:piecewise-program
  (make-deserialize-info
   (lambda e
     (piecewise-program 
      (first e)
      (for/list ([op (drop e 5)])
        (deserialize op))
      (second e)
      (third e)
      (deserialize (fourth e))
      (deserialize (fifth e))))
   (const #f)))
(struct piecewise-program program (pieces degree coefficients boundaries)
  #:transparent
  #:property prop:serializable
  (make-serialize-info
   (lambda (s)
     (vector-append
      (vector (program-inputs s)
              (piecewise-program-pieces s)
              (piecewise-program-degree s)
              (serialize (piecewise-program-coefficients s))
              (serialize (piecewise-program-boundaries s)))
      (for/vector ([op (program-instructions s)])
        (serialize op))))
   #'deserialize-info:piecewise-program
   #f
   (or (current-load-relative-directory) (current-directory))))

(define (piecewise-structure S)
  (define P (isketch-program S))
  (define coeffs (piecewise-program-coefficients P))
  (define bounds (piecewise-program-boundaries P))
  ; at least one of the highest-degree coefficients in one of 
  ; the pieces must be non-zero
  (when (> (piecewise-program-degree P) 0)
    (define deg-n-coeffs (for*/list ([piece coeffs] [coeff (last piece)]) coeff))
    (define degree-cond (apply || (map (lambda (x) (not (= x 0))) deg-n-coeffs)))
    (assert degree-cond))
  ; symmetry and structure constraints for branching conditions
  (when (> (piecewise-program-pieces P) 2)
    (for ([c1 bounds][i (- (length bounds) 1)])
      (define c2 (list-ref bounds (+ i 1)))
      ; symmetry breaking: place an order on the pieces
      (for ([c1i c1][c2i c2])
        (assert (<= c1i c2i)))
      ; structure constraint: conditions are not completely equal
      (assert (apply || (for/list ([c1i c1][c2i c2]) (not (= c1i c2i))))))))

; We depend on the cost function being additive as described above.
; To figure out the space, we just iterate along the worst-case for each
; axis to find bounds, and then use the cost function to do actual
; set membership testing in the now-bounded space.
(define (piecewise-subset v maxpieces maxdegree κ order)
  (define ref (curry piecewise-ref v))
  (lambda (c)
    (cond [(infinite? c)
           (if (false? order)
               (space v maxpieces maxdegree c κ)
               (ordered-space (space v maxpieces maxdegree c κ) (order (list maxpieces maxdegree))))]
          [else
           (define maxk (for/last ([k (in-range maxpieces)])
                          #:break (>= (κ (ref (list k 0)) '()) c)
                          k))
           (set! maxk (if maxk (add1 maxk) 0))
           (define maxn (for/last ([n (in-range maxdegree)])
                          #:break (>= (κ (ref (list 0 n)) '()) c)
                          n))
           (set! maxn (if maxn (add1 maxn) 0))
           (if (false? order)
               (space v maxk maxn c κ)
               (ordered-space (space v maxk maxn c κ) (order (list maxk maxn))))])))

(struct space (v maxk maxn maxκ κ)
  #:transparent
  #:property prop:sequence
  (lambda (self) (in-set self))
  #:methods gen:set
  [(define (set-count self)
     (match-define (space v maxk maxn maxκ κ) self)
     (if (or (infinite? maxk) (infinite? maxn))
         +inf.0
         (length (for/list ([i (in-set self)]) i))))
   (define (set-member? self idx)
     (match-let ([(space v maxk maxn maxκ κ) self]
                 [(list k n) idx])
       (and (< k maxk) (< n maxn) 
            (or (infinite? maxκ) (< (κ (piecewise-ref v (list k n)) '()) maxκ)))))
   (define (in-set self)
     (match-define (space v maxk maxn maxκ κ) self)
     (in-generator
      (for* ([idx (enumerate-cross-product/z (list maxk maxn))]
             #:when (< (κ (piecewise-ref v idx) '()) maxκ))
        (yield idx))))])

(define (piecewise-subset-no-cost v maxpieces maxdegree order)
  (define ref (curry piecewise-ref v))
  (define s (sequence->list (enumerate-cross-product/z (list maxpieces maxdegree))))
  (define ss (list->set s))
  (lambda (c)
    (if (false? order)
        ss
        (ordered-space ss (order (list maxpieces maxdegree))))))

; To get bounded constants, we walk over every symbolic constant in
; the program, and bound it. This only works because the PF implementation
; doesn't have any constants other than ones we want bounded.
(define (piecewise-post post)
  (lambda (p inputs)
    (post p inputs)
    (for ([inst (program-instructions p)])
      (match inst
        [(bv val) (when (term? val) 
                    (assert (< val (expt 2 15)))
                    (assert (< (- (expt 2 15)) val)))]
        [_        (void)]))))

(define (bvbounded)
  (define-symbolic* val number?)
  (bv val))
(define (extract-bvbounded-val op)
  (match op [(bv val) val]))

(define (piecewise-ref v idx)
  (match-define (list k n) idx)
  (set! k (add1 k))  ; 0 pieces not allowed
  
  ; list of coefficients for each piece.
  ; has k elements. each element has n+1 members, each of which is a coefficient
  ; for a given degree. since polynomials are over several inputs, each coefficient
  ; has v pieces, except the first, which is the constant coefficient.
  ; the inner-most lists are all the coefficients of the same degree in a particular piece.
  ; the constant coefficient is not included.
  (define piece-coeffs '())
  ; list of boundary conditions.
  ; has k-1 elements, each of which contains v terms.
  ; the inner-most lists are the boundary conditions necessary to select a particular piece.
  ; the boundaries are in the order they are tested by the program.
  (define boundaries '())
  
  (define (piece i)
    ; v*n coefficients, in the order 
    ;   x_1^1, x_2^1, ⋯, x_v^1, x_1^2, ⋯, x_v^2, ⋯, x_1^n, ⋯, x_v^n
    (define coeffs (for/list ([d n])
                     (for/list ([var v])
                       (bvbounded))))
    (define terms  (for*/list ([d n] [var v])
                     (define x (if (= d 0) var (+ v (* var (- n 1)) (- d 1))))
                     (bvmul x (+ i (* d v) var))))
    (define const  (bvbounded))
    (define sums   (for/list ([j (* v n)]) (bvadd (+ i (* v n) j) (+ i (* 2 v n) j))))
    (set! piece-coeffs 
          (append piece-coeffs 
            (list (append (list (extract-bvbounded-val const))
                          (for/list ([l coeffs]) 
                            (map extract-bvbounded-val l))))))
    (append (flatten coeffs) terms (list const) sums))
  
  (define vars
    (cond 
      [(= n 1) '()]
      [else 
       (apply append 
              (for/list ([i v])
                (cons
                 (bvmul i i)
                 (for*/list ([j (in-range (+ v (* i (- n 1)) 1) (+ v (* i (- n 1)) n -1))])
                   (bvmul i (- j 1))))))]))

  (define size  (+ (* 3 v n) 1))
  
  (define pieces 
    (let ([offset (+ v (length vars))])
       (apply append 
             (for/list ([j (in-range 0 (* size k) size)]) 
               (piece (+ offset j))))))
  
  (define cmps     
    (apply
     append 
     (for/list ([j (- k 1)])
       (define this-piece-boundaries '())
       (define ops
         (let ([offset (+ v (length vars) (length pieces) (* 2 v j) (* (- v 1) j) )])
           `(,@(apply append
                      (for/list ([i v])
                        (define op (bvbounded))
                        (set! this-piece-boundaries 
                              (append this-piece-boundaries (list (extract-bvbounded-val op))))
                        (list op
                              (bvslt i (+ offset (* 2 i))))))
             ,@(cond 
                 [(= v 1) '()]
                 [else 
                  (let* ([a-offset (+ offset (* 2 v))])
                    (cons
                     (bvand (+ offset 1) (+ offset 3))
                     (for/list ([i (in-range 2 v)])
                       (bvand (+ offset (* 2 i) 1) (+ a-offset i -2)))))]))))
       (set! boundaries (append (list this-piece-boundaries) boundaries))
       ops)))
          
  (define ites     
    (cond 
      [(> k 1)
       (let* ([c-offset (+ v (length vars) (length pieces))]
              [offset (+ c-offset (length cmps))])
         (cons 
          (ite (+ c-offset (* 2 v) (- v 2))
               (+ (* v n) size -1)
               (+ (* v n) (* 2 size) -1))
          (for/list ([j (in-range 1 (- k 1))])
            (ite (+ c-offset (* 2 v (+ j 1)) (* (- v 1) (+ j 1)) -1)
                 (+ (* v n) (* size (+ j 2)) -1)
                 (+ offset j -1)))))]
      [else '()]))

  (piecewise-program v (append vars pieces cmps ites) k n piece-coeffs boundaries))
