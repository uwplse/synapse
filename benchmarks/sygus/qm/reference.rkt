#lang s-exp rosette

(require "qm.rkt")

(define-syntax-rule (define-qm-problem (id [out] args ...) body ...)
  (begin
    (define (id #:order [order #f])
      (qm-ms
       (length '(args ...))
       (lambda (P xs)
         (let ([out (qm-output P xs)])
           (match xs
             [(list args ...) body ...])))
       #:order order))
    (provide id)))


(define-qm-problem (qm_area_sel_2 [out] x y ax ay bx by)
  (assert (= out
             (let* ([adx (- x ax)]
                    [ady (- y ay)]
                    [bdx (- x bx)]
                    [bdy (- y by)]
                    [aax (if (< adx 0) (- adx) adx)]
                    [aay (if (< ady 0) (- ady) ady)]
                    [bax (if (< bdx 0) (- bdx) bdx)]
                    [bay (if (< bdy 0) (- bdy) bdy)])
               (if (< (+ aax aay) (+ bax bay)) 1 0)))))

(define-qm-problem (qm_choose_01 [out] x)
  (assert (= out (if (<= x 0) 1 0))))

(define-qm-problem (qm_choose_yz [out] x y z)
  (assert (= out (if (<= x 0) y z))))

(define-qm-problem (qm_in_range [out] x y z)
  (assert (= out (if (and (< y x) (< x z)) 1 0))))

(define-qm-problem (qm_loop_1 [out] x)
  (assert (= out (if (<= x 0) 3 (- x 1)))))

(define-qm-problem (qm_loop_2 [out] x y)
  (assert (or (< x 0) (< y 0)
              (= out (if (= y 0) (if (= x 0) 3 (- x 1)) x)))))

(define-qm-problem (qm_loop_3 [out] x y z)
  (assert (or (< x 0) (< y 0) (< z y)
              (= out (if (and (= z 0) (= y 0)) (if (= x 0) 3 (- x 1)) x)))))

(define-qm-problem (qm_max2 [out] x y)
  (assert (= out (if (<= x y) y x))))

(define-qm-problem (qm_max3 [out] x y z)
  (assert (= out (if (and (>= x y) (>= x z)) x (if (>= y z) y z)))))

(define-qm-problem (qm_max4 [out] w x y z)
  (assert (= out (if (and (and (>= w x) (>= w y)) (>= w z)) w
                     (if (and (>= x y) (>= x z)) x 
                         (if (>= y z) y z)))))) 

(define-qm-problem (qm_max5 [out] v w x y z)
  (assert (= out (if (and (and (and (>= v w ) (>= v x)) (>= v y)) (>= v z)) v
                     (if (and (and (>= w x) (>= w y)) (>= w z)) w
                         (if (and (>= x y) (>= x z)) x 
                             (if (>= y z) y z)))))))

(define-qm-problem (qm_neg_1 [out] x)
  (assert (= out (if (< x 0) 1 0))))

(define-qm-problem (qm_neg_2 [out] x y)
  (assert (= out (if (and (< x 0) (< y 0)) 1 0))))

(define-qm-problem (qm_neg_3 [out] x y z)
  (assert (= out (if (and (< x 0) (and (< y 0) (< z 0))) 1 0))))

(define-qm-problem (qm_neg_4 [out] w x y z)
  (assert (= out (if (and (< w 0) (and (< x 0) (and (< y 0) (< z 0)))) 1 0))))

(define-qm-problem (qm_neg_5 [out] v w x y z)
  (assert (= out (if (and (< v 0) (and (< w 0) (and (< x 0) (and (< y 0) (< z 0))))) 1 0))))

(define-qm-problem (qm_neg_eq_1 [out] x)
  (assert (= out (if (<= x 0) 1 0))))

(define-qm-problem (qm_neg_eq_2 [out] x y)
  (assert (= out (if (and (<= x 0) (<= y 0)) 1 0))))

(define-qm-problem (qm_neg_eq_3 [out] x y z)
  (assert (= out (if (and (<= x 0) (and (<= y 0) (<= z 0))) 1 0))))

(define-qm-problem (qm_neg_eq_4 [out] w x y z)
  (assert (= out (if (and (<= w 0) (and (<= x 0) (and (<= y 0) (<= z 0)))) 1 0))))

(define-qm-problem (qm_neg_eq_5 [out] v w x y z)
  (assert (= out (if (and (<= v 0) (and (<= w 0) (and (<= x 0) (and (<= y 0) (<= z 0))))) 1 0))))
