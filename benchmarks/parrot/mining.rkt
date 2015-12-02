#lang s-exp rosette

(require "../../opsyn/bv/lang.rkt" "../../opsyn/metasketches/cost.rkt")

(provide ris-core ris-extension)

(define ops
  (list bvadd bvsub bvand bvor bvxor bvnot bvshl bvashr bvlshr bvneg bv bvredor
        bvmax bvmin bvabs bvsle bvslt bveq bvule bvult
        ite bvmul bvsdiv bvsrem bvudiv bvurem bvsqrt))

; Given a list of core BV instructions, returns a list of extension BV instructions 
; that are suitable for use with the Reduced Instruction Set (RIS) metasketch, 
; together with an additive cost function based on the given cost model.
; If no cost model is provided, sample-cost-model is used.
(define (ris-extension core [cost-model sample-cost-model])
  (sort (remove* core ops) < #:key cost-model))
  
; Given a reference implementation, returns a list of core BV instructions 
; that are suitable for use with the Reduced Instruction Set (RIS) metasketch, 
; together with an additive cost function based on the given cost model.
; If no cost model is provided, sample-cost-model is used.
(define (ris-core P [cost-model sample-cost-model])
  (remove-duplicates
   (for/fold ([core '()]) ([inst (program-instructions P)])
     (match inst
       [(bv n)       (if (> (abs n) 2) ; large constant
                         (list* bv core)
                         core)]
       [(bvadd _ _)  (list* bvadd core)]
       [(bvsub _ _)  (list* bvsub core)]
       [(bvand _ _)  (list* bvand core)]
       [(bvor  _ _)  (list* bvor core)]
       [(bvnot _)    (list* bvnot core)]
       [(bvshl _ _)  (list* bvshl core)]
       [(bvashr _ _) (list* bvashr core)]
       [(bvlshr _ _) (list* bvlshr core)]
       [(bvneg _)    (list* bvneg core)]
       [(bvredor _)  (list* bvredor core)]
       [(bvmax _ _)  (list* bvmax core)]
       [(bvmin _ _)  (list* bvmin core)]
       [(bvabs _)    (list* bvabs core)]
       [(bvxor _ _)  (list* bvxor core)]
       [(bvsle _ _)  (list* bvsle core)]
       [(bvslt _ _)  (list* bvslt core)]
       [(bveq _ _)   (list* bveq core)]
       [(bvule _ _)  (list* bvule core)]
       [(bvult _ _)  (list* bvult core)]
       [(ite _ _ _)  (list* ite core)]
       [(bvmul _ _)  (append (replace-if-cheaper bvmul (list bvadd bvsub bvshl) cost-model) core)]
       [(bvsdiv _ _) (append (replace-if-cheaper bvsdiv (list bvsub bvashr bvlshr) cost-model) core)]
       [(bvsrem _ _) (append (replace-if-cheaper bvsrem (list bvsub bvashr bvlshr) cost-model) core)]
       [(bvudiv _ _) (append (replace-if-cheaper bvudiv (list bvsub bvashr bvlshr) cost-model) core)]
       [(bvurem _ _) (append (replace-if-cheaper bvurem (list bvsub bvashr bvlshr) cost-model) core)]
       [(bvsqrt _)   (append (replace-if-cheaper bvsqrt (list bvabs bvmax bvmin) cost-model) core)]))))

(define (replace-if-cheaper inst insts cost-model)
  (if (andmap (compose1 (curry > (cost-model inst)) cost-model) insts)
      insts
      (list inst)))

  