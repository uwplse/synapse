#lang s-exp rosette

(require "../../opsyn/metasketches/cost.rkt"
         "../../opsyn/metasketches/piecewise.rkt"
         "../../opsyn/bv/lang.rkt"
         "fft.rkt"
         math)

(provide least-squares-ms)

; Cost function for least-squares regression:
;   sum the errors for each input-output example
(define (least-squares-cost points)
  (lambda (P inputs)
    (apply + (for/list ([io points])
               (abs (- (interpret P (list (car io)))
                       (cadr io)))))))

; Create a least-squares regression metasketch with the given
; maximum topology (pieces and degree) and input-output examples.
(define (least-squares-ms #:pieces pieces 
                          #:degree degree 
                          #:points points)
  (piecewise/cost #:maxpieces pieces
                  #:maxdegree degree
                  #:arity 1
                  #:post void
                  #:cost (least-squares-cost points)))
