#lang s-exp rosette

(require "reference.rkt"  
         "../../opsyn/bv/lang.rkt"  
         "../../opsyn/metasketches/superoptimization.rkt"  
         "../../opsyn/metasketches/cost.rkt"
         (only-in rosette [bveq rosette-bveq]))

(provide hd-d5)


; Returns a d5 superoptimization metasketch for the 
; given HD benchmark.  The metasketch can be finite
; (with the upper bound being the reference length)
; or infinite.   The optional cost-model argument is
; as specified for the superopt∑ metasketch procedure. 
; By default, the returned metasketch assigns the cost 
; of 1 to all instructions.
(define (hd-d5 prog 
               #:finite? [finite? #t] 
               #:cost-model [cost-model constant-cost-model])
  (superopt∑ #:instructions bvops;(if (or (eq? prog hd14) (eq? prog hd15)) hd14-d5 bvops)
             #:maxlength (if finite? (length (program-instructions prog)) +inf.0)
             #:arity (program-inputs prog)
             #:input-type (bitvector (current-bitwidth))
             #:pre   (if (eq? prog hd20) (lambda (inputs) (assert (not (= (car inputs) 0)))) void)
             #:post  (lambda (P inputs)
                       (assert (rosette-bveq (interpret prog inputs)
                                             (interpret P inputs))))
             #:cost-model cost-model))

; Bitvector logic operators that appear in d5 benchmarks.
(define bvops 
  (list (bv 0) (bv 1) (bv 31)
        bvadd bvsub bvand bvor bvnot bvshl bvashr bvlshr 
        bvneg bvredor bvxor bvsle bvslt bveq bvule bvult 
        bvmul bvsdiv bvsrem bvudiv bvurem))

(define hd14-d5
  (list bvnot bvxor bvand bvor bvneg bvadd bvmul bvudiv  
        bvurem bvlshr bvashr bvshl bvsdiv bvsrem bvsub
        (bv -1) (bv 0) (bv 1) (bv 31)))

    
  
