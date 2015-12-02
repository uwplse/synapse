#lang s-exp rosette

(require "../../opsyn/bv/lang.rkt" "mining.rkt" "specs.rkt"
         "../../opsyn/metasketches/ris.rkt" "../../opsyn/metasketches/bdf.rkt" "../../opsyn/metasketches/cost.rkt")

(provide dist3 dist3-ris dist3-bdf)

; This program measures the distance between 2 color points.
; The inputs to the program are 6 RGB values in range [0,255].

(define dist3 ; 6 inputs are stored in registers [0..5]  
  (program 6
   (list
    #| 6 |# (bvsub 0 3)
    #| 7 |# (bvmul 6 6)
    #| 8 |# (bvsub 1 4)
    #| 9 |# (bvmul 8 8)
    #|10 |# (bvsub 2 5)
    #|11 |# (bvmul 10 10)
    #|12 |# (bvadd 7 9)
    #|13 |# (bvadd 11 12)
    #|14 |# (bvsqrt 13))))

; Returns a RIS metasketch for the dist3 kernel, 
; with respect to the given quality constraint.  The 
; quality procedure should take two values---the output 
; of the synthesized program and the output of the reference 
; specification---and emit the desired correctness assertions 
; that relate them.  For example quality procedures, see 
; specs.rkt.  The maxlength and cost-model parameters 
; are as specified for the ris metasketch.
(define (dist3-ris
         #:quality quality 
         #:maxlength [maxlength +inf.0]
         #:cost-model [cost-model sample-cost-model])
  (define core (ris-core dist3 cost-model))
  (define ext (ris-extension core cost-model))
  (ris #:core core
       #:extension ext
       #:maxlength maxlength
       #:arity (program-inputs dist3)
       #:pre  (range 0 255)
       #:post (lambda (P inputs)
                (quality (interpret P inputs) (interpret dist3 inputs)))
       #:cost-model cost-model))

; Returns a BDF metasketch for the dist3 kernel, 
; with respect to the given quality constraint.  The 
; quality procedure should take two values---the output 
; of the synthesized program and the output of the reference 
; specification---and emit the desired correctness assertions 
; that relate them.  For example quality procedures, see 
; specs.rkt.  The cost-model parameter is as specified for the ris metasketch.
(define (dist3-bdf
         #:quality quality 
         #:cost-model [cost-model sample-cost-model])
  (define core (ris-core dist3 cost-model))
  (define ext (ris-extension core cost-model))
  (bdf #:reference dist3
       #:core core
       #:extension ext
       #:pre  (range 0 255)
       #:post (lambda (P inputs)
                (quality (interpret P inputs) (interpret dist3 inputs)))
       #:cost-model cost-model))
