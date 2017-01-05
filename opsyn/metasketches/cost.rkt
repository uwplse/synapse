#lang s-exp rosette

(require rosette/lib/match
         "../bv/lang.rkt" "../engine/metasketch.rkt")

(provide ∑cost sample-cost-model constant-cost-model sample-costs static-cost-model lowest-cost)


; Given a function from instructions or instruction constructors to costs, returns a function 
; κ : program? -> any/c -> number?, which takes as input a BV program and returns 
; the sum of all instruction costs in that program, according to the given cost model.  
; The function κ also takes a list of program inputs, which are ignored.
; The cost-model argument is optional.  If one is not provided, the sample-cost-model  
; function is used.
(define (∑cost [cost-model sample-cost-model])
  (define (κ prog inputs)
    (apply + (map cost-model (program-instructions prog))))
  κ)

; Given a cost-model function and a list of instructions, returns 
; the cost of the cheapest instruction in that list according to the given cost model.
; The input list may contain a mix of instruction? objects and instruction constructor 
; procedures.
(define (lowest-cost insts cost-model)
  (for/fold ([cost +inf.0])
            ([inst insts])
    (min cost (cost-model inst))))

; A sample cost table.
(define sample-costs
  (hash bv 1 bvadd 1 bvsub 1 bvand 1 bvor 1 bvxor 1 bvnot 1 bvshl 1 bvashr 1 bvlshr 1 bvneg 1 bvredor 1
        bvmax 2 bvmin 2 bvabs 2 bvsle 2 bvslt 2 bveq  2 bvule 2 bvult 2
        ite 4 bvmul 4 bvsdiv 8 bvsrem 8 bvudiv 8 bvurem 8 bvsqrt 16))



; Returns a cost model function for the given map from instruction types to costs.  
; The resulting function takes either instruction?  instances or instruction constructors, 
; and returns the cost of the given instruction or any instruction created with the 
; given constructor.
(define (static-cost-model instruction-cost)
  (lambda (inst)
    (match inst
      [(bv _)       (hash-ref instruction-cost bv)]
      [(bvadd _ _)  (hash-ref instruction-cost bvadd)]
      [(bvsub _ _)  (hash-ref instruction-cost bvsub)]
      [(bvand _ _)  (hash-ref instruction-cost bvand)]
      [(bvor  _ _)  (hash-ref instruction-cost bvor)]
      [(bvnot _)    (hash-ref instruction-cost bvnot)]
      [(bvshl _ _)  (hash-ref instruction-cost bvshl)]
      [(bvashr _ _) (hash-ref instruction-cost bvashr)]
      [(bvlshr _ _) (hash-ref instruction-cost bvlshr)]
      [(bvneg _)    (hash-ref instruction-cost bvneg)]
      [(bvredor _)  (hash-ref instruction-cost bvredor)]
      [(bvmax _ _)  (hash-ref instruction-cost bvmax)]
      [(bvmin _ _)  (hash-ref instruction-cost bvmin)]
      [(bvabs _)    (hash-ref instruction-cost bvabs)]
      [(bvxor _ _)  (hash-ref instruction-cost bvxor)]
      [(bvsle _ _)  (hash-ref instruction-cost bvsle)]
      [(bvslt _ _)  (hash-ref instruction-cost bvslt)]
      [(bveq _ _)   (hash-ref instruction-cost bveq)]
      [(bvule _ _)  (hash-ref instruction-cost bvule)]
      [(bvult _ _)  (hash-ref instruction-cost bvult)]
      [(ite _ _ _)  (hash-ref instruction-cost ite)]
      [(bvmul _ _)  (hash-ref instruction-cost bvmul)]
      [(bvsdiv _ _) (hash-ref instruction-cost bvsdiv)]
      [(bvsrem _ _) (hash-ref instruction-cost bvsrem)]
      [(bvudiv _ _) (hash-ref instruction-cost bvudiv)]
      [(bvurem _ _) (hash-ref instruction-cost bvurem)]
      [(bvsqrt _)   (hash-ref instruction-cost bvsqrt)]
      [_            (hash-ref instruction-cost inst)])))

(define sample-cost-model (static-cost-model sample-costs))
(define constant-cost-model (const 1))


