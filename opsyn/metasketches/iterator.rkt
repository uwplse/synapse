#lang racket

(require racket/generator)

(provide enumerate-cross-product/z enumerate-cross-product/sum)

; Returns a sequence that lazily enumerates all points in 
; the space D1 × ... × Dn, where n = (length xs) and Di is 
; the sequence [0..(list-ref xs i)).  The list xs
; must contain either natural numbers, to indicate sizes of 
; finite dimensions, or +inf.0, to indicate an infinite
; dimension.  The cross-product is enumerated in breadth-first order.
; In particular, the enumeration order is such that a point P1 
; is guaranteed to appear before a point P2 whenever P1(i) ≤ P2(i) 
; for all i ∈ [0..n).
(define (enumerate-cross-product/z xs)
  (define-values (infinite finite) (partition infinite? xs))
  (cond 
    [(null? infinite) (enumerate-finite-cross-product xs)]
    [(null? finite)   (enumerate-infinite-cross-product (length xs))]
    [else
     (in-generator
      (for* ([inf (enumerate-infinite-cross-product (length infinite))]
             [fin (enumerate-finite-cross-product finite)])
        (yield
         (let assemble ([fin fin] [inf inf] [xs xs])
           (cond 
             [(null? xs) xs]
             [(infinite? (car xs)) (cons (car inf) (assemble fin (cdr inf) (cdr xs)))]
             [else (cons (car fin) (assemble (cdr fin) inf (cdr xs)))])))))]))


(define-syntax-rule (enumerate [i d] ...) 
  (in-generator (for* ([i d] ...) (yield (list i ...)))))

; Returns a sequence that lazily enumerates the finite cross 
; product of values in the given list of finite streams.
(define (enumerate-finite-cross-product xs)
  (match xs
    [(list)         (enumerate)]
    [(list x)       (enumerate [i x])]
    [(list x y)     (enumerate [i x][j y])]
    [(list x y z)   (enumerate [i x][j y][k z])]
    [(list w x y z) (enumerate [h w][i x][j y][k z])]
    [_
     (in-generator 
      (for* ([i (car xs)] [v (enumerate-finite-cross-product (cdr xs))])
        (yield (cons i v))))]))

; Returns an infinite sequence that enumerates all 
; points in the space N^d, where N are the natural 
; numbers and points are represented as lists of length d.
; The sequence enumerates points in breadth-first order, by 
; enumerating points in the difference of the hypercubes of 
; increasing size:  [0, 1]^d, [0, 2]^d \ [0, 1]^d, 
; ..., [0, i]^d \ [0, i-1]^d.
(define (enumerate-infinite-cross-product d)
  (in-generator
   (for* ([i (in-naturals 0)] 
          [j (in-range 1 (expt 2 d))]
          [v (enumerate-finite-cross-product
                (for/list ([k (in-range (- d 1) -1 -1)]) 
                  (if (bitwise-bit-set? j k) 
                      (in-value i) 
                      (in-range 0 i))))])
       (yield v))))
  
; Returns a sequence that lazily enumerates all points in 
; the space D1 × ... × Dn, where n = (length xs) and Di is 
; the sequence [0..(list-ref xs i)).  The list xs
; must contain either natural numbers, to indicate sizes of 
; finite dimensions, or +inf.0, to indicate an infinite
; dimension.  The cross-product is enumerated in a summation order.
; In particular, the enumeration order is such that a point P1 
; is guaranteed to appear before a point P2 whenever
; ∑_{i=1}^n P1(i) ≤ ∑_{i=1}^n P2(i).
(define (enumerate-cross-product/sum xs)
 (in-generator
  (define (rec acc accsum xs* sum)
    (cond [(= (length acc) (sub1 (length xs)))
           (when (< sum (car xs*))
             (yield (append acc (list sum))))]
          [else (for ([x (in-range (min (car xs*) (+ sum 1)))])
                  (rec (append acc (list x)) (+ accsum x) (cdr xs*) (- sum x)))]))
  (for ([sum (in-range (add1 (apply + (map sub1 xs))))])
    (rec '() 0 xs sum))))
