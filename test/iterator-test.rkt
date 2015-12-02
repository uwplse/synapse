#lang racket

(require "../opsyn/metasketches/iterator.rkt"
         rackunit "test-runner.rkt")

; Take n points from the generator.
(define (generator-take g n)
  (for/list ([i n]) (g)))

(define (test-z xs)
 (test-case (format "test-z: ~a" xs)
  (define ref (for/set ([i (enumerate-cross-product/z '(3 3 3))][j 27]) i))
  (define seq (for/set ([i (enumerate-cross-product/z xs)][j 27]) i))
  (check equal? ref seq)))

(define (z-tests)
  (test-z '(3 +inf.0 +inf.0))
  (test-z '(+inf.0 3 +inf.0))
  (test-z '(+inf.0 +inf.0 3))
  (test-z '(+inf.0 3 3))
  (test-z '(3 +inf.0 3))
  (test-z '(3 3 +inf.0))
  (test-z '(+inf.0 +inf.0 +inf.0))
  )

(define (manual-seq-1 xs)
  (for/list ([i (car xs)]) (list i)))
(define (manual-seq-2 xs)
  (define seq '())
  (for ([s (apply + xs)])
    (for ([i (in-range (first xs))])
      (for ([j (in-range (second xs))]
            #:when (= (+ i j) s))
        (set! seq (append seq (list (list i j)))))))
  seq)
(define (manual-seq-3 xs)
  (define seq '())
  (for ([s (apply + xs)])
    (for ([i (in-range (first xs))])
      (for ([j (in-range (second xs))])
        (for ([k (in-range (third xs))]
              #:when (= (+ i j k) s))
        (set! seq (append seq (list (list i j k))))))))
  seq)

(define (test-sum xs)
 (test-case (format "test-sum: ~a" xs)
  (define seq (case (length xs)
                [(1) (manual-seq-1 xs)]
                [(2) (manual-seq-2 xs)]
                [(3) (manual-seq-3 xs)]
                [else (error 'test-sum "no manual seq generator for length ~a" (length xs))]))
  (set! seq (list->set seq))
  
  (define gen-seq (for/list ([x (enumerate-cross-product/sum xs)][i (add1 (apply * xs))]) x))
  ; check the elements are the same
  (check equal? (length gen-seq) (apply * xs))
  (check equal? seq (list->set gen-seq))
  ; check the invariant: P1 before P2 if ∑_{i=1}^n P1(i) ≤ ∑_{i=1}^n P2(i)
  (define current-sum 0)
  (for ([x gen-seq])
    (check-true (or (= (apply + x) current-sum) (= (apply + x) (add1 current-sum))))
    (set! current-sum (apply + x)))))

(define (test-sum-inf xs)
 (test-case (format "test-sum-inf: ~a" xs)
  (define seq (for/list ([x (enumerate-cross-product/sum xs)][i 100]) x))
  ; infinite sequences don't terminate
  (check equal? (length seq) 100)
  (define current-sum 0)
  (for ([x seq])
    ; check the invariant: P1 before P2 if ∑_{i=1}^n P1(i) ≤ ∑_{i=1}^n P2(i)
    (check-true (or (= (apply + x) current-sum) (= (apply + x) (add1 current-sum))))
    (set! current-sum (apply + x))
    ; check all bounds were satisfied
    (for ([i x][bnd xs])
      (check-true (< i bnd))))))

(define (sum-tests)
  (test-sum '(0))
  (test-sum '(1))
  (test-sum '(10))
  (test-sum '(0 0))
  (test-sum '(1 0))
  (test-sum '(0 1))
  (test-sum '(1 1))
  (test-sum '(10 0))
  (test-sum '(0 10))
  (test-sum '(10 1))
  (test-sum '(1 10))
  (test-sum '(10 10))
  (test-sum '(10 8))
  (test-sum '(0 0 0))
  (test-sum '(0 0 1))
  (test-sum '(1 0 0))
  (test-sum '(10 10 10))
  (test-sum '(10 9 8))
  (test-sum-inf '(+inf.0))
  (test-sum-inf '(+inf.0 +inf.0))
  (test-sum-inf '(+inf.0 5))
  (test-sum-inf '(5 +inf.0))
  (test-sum-inf '(+inf.0 +inf.0 +inf.0))
  (test-sum-inf '(+inf.0 5 3))
  (test-sum-inf '(3 5 +inf.0))
  )

(define/provide-test-suite
  iterator-tests
  (z-tests)
  (sum-tests)
  )

(run-tests-quiet iterator-tests)
