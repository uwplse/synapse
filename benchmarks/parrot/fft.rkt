#lang s-exp rosette

(require "../../opsyn/bv/lang.rkt" "specs.rkt"
         "../../opsyn/metasketches/piecewise.rkt" "../../opsyn/metasketches/cost.rkt")

(provide fftSin fftCos io
         fft-metasketch
         fft-sin-metasketch fft-cos-metasketch)

(define (fftSin x)
  (sin (* -2 pi x)))
(define (fftCos x)
  (cos (* -2 pi x)))

; Approximate fftSin or fftCos over a given discretized interval.
(define (io ref start stop [step 50])
  (define scale 100)
  (define sstart (inexact->exact (floor (* start scale))))
  (define sstop (inexact->exact (ceiling (* stop scale))))
  (for/list ([x (in-range sstart (add1 sstop) step)])
    (define in (/ x 100))
    (define out (* 100 (ref in)))
    (cons (list x) (inexact->exact (floor out)))))
  
; Returns a piecewise metasketch for the given FFT function
; with respect to the given quality constraint. The quality
; procedure should take two values---the output of the synthesized
; program and the output of the reference specification---and
; assert the desired correctness properties over them. The
; maxpieces, maxdegree, and cost-model parameters are as specified
; for the piecewise metasketch.
(define (fft-metasketch
         #:reference reference
         #:start [start 0]
         #:stop  [stop 0.5]
         #:step  [step 1]
         #:quality quality
         #:maxpieces [maxpieces +inf.0]
         #:maxdegree [maxdegree +inf.0]
         #:cost-model [cost-model sample-cost-model]
         #:order [order #f])
  (define points (io reference start stop step))
  (piecewise
   #:maxpieces maxpieces
   #:maxdegree maxdegree
   #:arity 1
   #:post (fft-post quality points)
   #:cost-model cost-model
   #:order order))

(define (fft-post quality points)
  (lambda (P inputs)
    (for ([io points])
      (assert (quality (interpret P (car io)) (cdr io))))))

; The actual settings used for AppSyn
(define (fft-sin-metasketch [e 1] [order #f])
  (fft-metasketch
   #:reference fftSin
   #:start 0.0
   #:stop 0.5
   #:step 1
   #:quality (relaxed e)
   #:order order))
(define (fft-cos-metasketch [e 1] [order #f])
  (fft-metasketch
   #:reference fftCos
   #:start -0.25
   #:stop 0.25
   #:step 1
   #:quality (relaxed e)
   #:order order))