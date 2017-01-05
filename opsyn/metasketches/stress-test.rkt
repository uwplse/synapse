#lang s-exp rosette

(require "../engine/metasketch.rkt" "../bv/lang.rkt" "imetasketch.rkt")

(provide test-metasketch tm-shuffled-order)

(define (test-metasketch #:length len #:order order)
  (imeta #:arity 1
         #:ref tm-ref
         #:subset (tm-make-subset len order)
         #:post tm-post
         #:structure void
         #:cost tm-cost
         #:minbw tm-minbw))

(define (tm-ref idx)
  (program 1
    (for/fold ([prog '()])
              ([i (car idx)])
      (define-symbolic* coeff integer?)
      (append prog (list (bv coeff) (bvadd (* 2 i) (+ (* 2 i) 1)))))))

(define (tm-make-subset len order)
  (lambda (cost)
    (space len cost order)))

(define (tm-shuffled-order len)
  (shuffle (range 1 len)))

(define (tm-post P inputs)
 (define-values (vals assts)
   (for/lists (vals assts)
     ([op (program-instructions P)] #:when (bv? op))
     (values (unary-r1 op)
             (and (> (unary-r1 op) 0)
                      (< (unary-r1 op) (expt 2 8))))))
  (assert (or (= (apply + vals) 32)
              (apply && assts))))

(define (tm-cost P inputs)
  (apply + (for/list ([op (program-instructions P)] #:when (bv? op))
             (unary-r1 op))))

(define (tm-minbw S) 16)

;(struct nondet-space (len c)
;  #:transparent
;  #:property prop:sequence
;  (lambda (self) (in-set self))
;  #:methods gen:set
;  [(define (set-count self)
;     (min (nondet-space-len self) (nondet-space-c self)))
;   (define (set-member? self idx)
;     (and (<= 1 (car idx)) (<= (car idx) (set-count self))))
;   (define (in-set self)
;     (let ([all (range 1 (+ (set-count self)))])
;       (sequence-map list (shuffle all))))])

(struct space (len c order)
  #:transparent
  #:property prop:sequence
  (lambda (self) (in-set self))
  #:methods gen:set
  [(define (set-count self)
     (min (space-len self) (space-c self)))
   (define (set-member? self idx)
     (and (<= 1 (car idx)) (<= (car idx) (set-count self))))
   (define (in-set self)
     (let ([pred (lambda (i) (set-member? self (list i)))])
       (sequence-map list (filter pred (space-order self)))))])
