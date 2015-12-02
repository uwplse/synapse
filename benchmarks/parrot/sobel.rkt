#lang s-exp rosette

(require "../../opsyn/bv/lang.rkt" "mining.rkt" "specs.rkt"
         "../../opsyn/metasketches/ris.rkt" "../../opsyn/metasketches/cost.rkt")

(provide sobel-x sobel-y sobel-metasketch)

(define x
  '{{ -1 -2 -1}
    {  0  0  0}
    {  1  2  1}})

(define y
  '{{ -1 0 1}
    { -2 0 2} 
    { -1 0 1}})

; Constructs a map from values [-2, 2] to the 
; registers into which they are loaded by the 
; convolve function.
(define val->reg 
  (for/hash ([val (in-range -2 3)] 
             [reg (in-range 9 14)])
    (values val reg)))

; Returns the register that holds the input w[i, j] 
; in the convolve function.
(define (w i j) (+ (* 3 i) j))

; Returns the register that holds t[i, j] (where t 
; is the matrix x or y) in the convolve function.
(define (k t i j)
  (hash-ref val->reg (list-ref (list-ref t i) j)))

; Returns a program that implements the convolution in 
; the Sobel kernel with respect to the given matrix of constants (x or y). 
; The kernel takes as input 9 values in the range [0..255].
(define (convolve t)
  (program 9
   (list
    #|9|#  (bv -2)
    #|10|# (bv -1)
    #|11|# (bv 0)
    #|12|# (bv 1)
    #|13|# (bv 2)
    #|14|# (bvmul (w 0 0) (k t 0 0))
    #|15|# (bvmul (w 0 1) (k t 1 0))
    #|16|# (bvmul (w 0 2) (k t 2 0))
    #|17|# (bvmul (w 1 0) (k t 0 1))
    #|18|# (bvmul (w 1 1) (k t 1 1))
    #|19|# (bvmul (w 1 2) (k t 2 1))
    #|20|# (bvmul (w 2 0) (k t 0 2))
    #|21|# (bvmul (w 2 1) (k t 1 2))           
    #|22|# (bvmul (w 2 2) (k t 2 2))
    #|23|# (bvadd 14 15)
    #|24|# (bvadd 23 16)
    #|25|# (bvadd 24 17)
    #|26|# (bvadd 25 18)
    #|27|# (bvadd 26 19)           
    #|28|# (bvadd 27 20) 
    #|29|# (bvadd 28 21) 
    #|30|# (bvadd 29 22)))) 

; Programs that implement convolution in the 
; Sobel kernel with respect to the matrices x and y.
(define sobel-x (convolve x))
(define sobel-y (convolve y))

; Returns a RIS metasketch for the specified Sobel kernel, 
; with respect to the given quality constraint.  The 
; quality procedure should take two values---the output 
; of the synthesized program and the output of the reference 
; specification---and emit the desired correctness assertions 
; that relate them.  For example quality procedures, see 
; specs.rkt.  The maxlength and cost-model parameters 
; are as specified for the ris metasketch.
(define (sobel-metasketch 
         #:reference reference 
         #:quality quality 
         #:maxlength [maxlength +inf.0]
         #:cost-model [cost-model sample-cost-model]
         #:order [order #f])
  (define core (ris-core reference cost-model))
  (define ext (ris-extension core cost-model))
  (ris #:core core
       #:extension ext
       #:maxlength maxlength
       #:arity (program-inputs reference)
       #:pre  (range 0 255)
       #:post (lambda (P inputs)
                (quality (interpret P inputs) (interpret reference inputs)))
       #:cost-model cost-model
       #:order order))
