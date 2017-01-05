#lang s-exp rosette

(require "reference.rkt"  
         "../../opsyn/bv/lang.rkt"  
         "../../opsyn/metasketches/superoptimization.rkt"  
         "../../opsyn/metasketches/cost.rkt")

(provide hd-d0)


; Returns a d0 superoptimization metasketch for the 
; given HD benchmark.  The metasketch can be finite
; (with the upper bound being the reference length)
; or infinite.  The optional cost-model argument is
; as specified for the superopt∑ metasketch procedure. 
; By default, the returned metasketch assigns the cost 
; of 1 to all instructions.
(define (hd-d0 prog 
               #:finite? [finite? #t] 
               #:cost-model [cost-model constant-cost-model])
  (define insts (program-instructions prog))  
  (superopt∑ #:instructions (remove-duplicates (map instruction->type insts))
             #:maxlength (if finite? (length insts) +inf.0)
             #:arity (program-inputs prog)
             #:pre   (if (eq? prog hd20) (lambda (inputs) (assert (not (= (car inputs) 0)))) void)
             #:post  (lambda (P inputs)
                       (assert (= (interpret prog inputs) (interpret P inputs))))
             #:cost-model cost-model))
            

; Returns the constructor procedure that was used to 
; create the given instruction, or the instruction itself 
; if it is a constant (bv _).  
; The instruction must be concrete, since we are using (fast) 
; Racket matching instead of (slow) Rosette matching provided 
; by rosette/lib/match.
(define (instruction->type inst)
  (match inst
    [(bv _)       inst]
    [(bvadd _ _)  bvadd]
    [(bvsub _ _)  bvsub]
    [(bvand _ _)  bvand]
    [(bvor  _ _)  bvor]
    [(bvnot _)    bvnot]
    [(bvshl _ _)  bvshl]
    [(bvashr _ _) bvashr]
    [(bvlshr _ _) bvlshr]
    [(bvneg _)    bvneg]
    [(bvredor _)  bvredor]
    [(bvmax _ _)  bvmax]
    [(bvmin _ _)  bvmin]
    [(bvabs _)    bvabs]
    [(bvxor _ _)  bvxor]
    [(bvsle _ _)  bvsle]
    [(bvslt _ _)  bvslt]
    [(bveq _ _)   bveq]
    [(bvule _ _)  bvule]
    [(bvult _ _)  bvult]
    [(ite _ _ _)  ite]
    [(bvmul _ _)  bvmul]
    [(bvsdiv _ _) bvsdiv]
    [(bvsrem _ _) bvsrem]
    [(bvudiv _ _) bvudiv]
    [(bvurem _ _) bvurem]
    [(bvsqrt _)   bvsqrt]))
    
  
