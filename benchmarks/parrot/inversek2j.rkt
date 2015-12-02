#lang s-exp rosette

(require "../../opsyn/bv/lang.rkt" "specs.rkt"
         "../../opsyn/metasketches/piecewise.rkt" "../../opsyn/metasketches/cost.rkt")

(provide inversek2j-theta1 inversek2j-theta2
         inversek2j-metasketch inversek2j-theta1-metasketch inversek2j-theta2-metasketch)

(define l1 .5)
(define l2 .5)
(define (inversek2j-theta1 x y)
  ;*theta2 = acos(((x * x) + (y * y) - (l1 * l1) - (l2 * l2))/(2 * l1 * l2));
  ;*theta1 = asin((y * (l1 + l2 * cos(*theta2)) - x * l2 * sin(*theta2))/(x * x + y * y));
  (define theta2 (acos (/ (- (+ (* x x) (* y y)) (* l1 l1) (* l2 l2)) (* 2 l1 l2))))
  (define theta1 (asin (/ (- (* y (+ l1 (* l2 (cos theta2)))) (* x l2 (sin theta2))) (+ (* x x) (* y y)))))
  theta1)
(define (inversek2j-theta2 x y)
  ;*theta2 = acos(((x * x) + (y * y) - (l1 * l1) - (l2 * l2))/(2 * l1 * l2));
  (define theta2 (acos (/ (- (+ (* x x) (* y y)) (* l1 l1) (* l2 l2)) (* 2 l1 l2))))
  theta2)

; Approximate inversek2j over a given discretized interval.
(define (io ref start stop [step 20])
  (define scale 100)
  (define sstart (inexact->exact (floor (* start scale))))
  (define sstop (inexact->exact (ceiling (* stop scale))))
  (define period
    (for*/list ([x (in-range sstart (add1 sstop) step)]
                [y (in-range sstart (add1 sstop) step)]
                #:unless (or (and (= x 0) (= y y))
                             (not (real? (ref (/ x 100.0) (/ y 100.0))))))
      (cons (list x y) (inexact->exact (round (* 100 (ref (/ x 100.0) (/ y 100.0))))))))
  (take period (/ (length period) 2)))

; Returns a piecewise metasketch for the given inversek2j function
; with respect to the given quality constraint. The quality
; procedure should take two values---the output of the synthesized
; program and the output of the reference specification---and
; assert the desired correctness properties over them. The
; maxpieces, maxdegree, and cost-model parameters are as specified
; for the piecewise metasketch.
(define (inversek2j-metasketch
         #:reference reference
         #:start [start -1]
         #:stop  [stop 1]
         #:step  [step 20]
         #:quality quality
         #:maxpieces [maxpieces +inf.0]
         #:maxdegree [maxdegree +inf.0]
         #:cost-model [cost-model sample-cost-model]
         #:order [order #f])
  (define points (io reference start stop step))
  (piecewise
   #:maxpieces maxpieces
   #:maxdegree maxdegree
   #:arity 2
   #:post (inversek2j-post quality points)
   #:cost-model cost-model
   #:order order))

(define (inversek2j-post quality points)
  (lambda (P inputs)
    (for ([io points])
      (assert (quality (interpret P (car io)) (cdr io))))))

; The actual settings used for AppSyn
(define (inversek2j-theta1-metasketch [e 1] [order #f])
  (inversek2j-metasketch
   #:reference inversek2j-theta1
   #:start -1.0
   #:stop 1.0
   #:step 20
   #:quality (relaxed e)
   #:order order))
(define (inversek2j-theta2-metasketch [e 1] [order #f])
  (inversek2j-metasketch
   #:reference inversek2j-theta2
   #:start -1.0
   #:stop 1.0
   #:step 20
   #:quality (relaxed e)
   #:order order))