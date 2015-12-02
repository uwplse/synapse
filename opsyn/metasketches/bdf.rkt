#lang s-exp rosette

(require
  racket/generator
  "imetasketch.rkt" "cost.rkt" "superoptimization.rkt" "ris.rkt"
  "../engine/metasketch.rkt" "../engine/eval.rkt" "../engine/util.rkt"
  "../bv/lang.rkt" "../bv/hole.rkt" "../bv/lib.rkt")

(provide bdf)

; This procedure constructs a bounded dataflow (BDF) metasketch 
; that represents a family of sketches for a subset of the BV language, 
; and for an additive cost function based on the given cost model.
; Each sketch in the family represents all programs of a fixed length k, 
; in which each instruction is drawn from the given subset of BV, and 
; is constrained to read only a specific subset of registers.  In particular, 
; the BDF sketch is derived from a reference program R, and an instruction 
; at the index i is allowed to read only the registers that are read by the 
; the ith instruction in R.
; 
; The procedure constructs a metasketch M from the following inputs:
;
; * reference : program? the reference program used to constrain the arity 
; and dataflow of programs in M.
;
; * core : (listof instruction?) is the list of core instructions that 
; may appear in any program drawn from M.  The core list must be non-empty.  
;
; * extension : (listof (or/c unary? binary? ternary?)) is the 
; list of additional instructions that may appear in a program drawn from M.  
; Extension instructions must be different from the core instructions.
; 
; * pre : (listof number?) -> void? emits assertions on (symbolic)  
; inputs that represent preconditions for all programs in M.
;
; * post : program? -> (listof number?) -> void? emits assertions that 
; constrain the output of all programs in M when applied to 
; (symbolic) inputs.
; 
; * cost-model : (or/c procedure? instruction?) -> natural-number/c
; is a function that maps each instruction constructor or instance in BV
; to a natural number representing its cost.
(define (bdf #:reference R
             #:core core 
             #:extension extension
             #:pre [pre void] 
             #:post [post void]
             #:cost-model [cost-model sample-cost-model])
  (imeta
   #:arity (program-inputs R)
   #:subset (bdf-subset R core extension cost-model)
   #:pre pre
   #:post post
   #:structure (bdf-structure R extension)
   #:cost (∑cost cost-model)
   #:ref  (bdf-ref R core extension)
   #:minbw (const 16)))

(define (make-bdf-minbw R)
  (const (+ 1 (integer-length (+ (program-inputs R) (length (program-instructions R)))))))

(define (bdf-ref R core extension)
  (define arity (program-inputs R))
  (define spec (program-instructions R))
  (lambda (idx) 
    (define insts (append core (take extension (first idx))))
    (program 
     arity 
     (for/list ([line spec])
       (cond [(bv? line)     (??instruction (list bv))]
             [(unary? line)  (??instruction insts (list (r1 line)))]
             [(binary? line) (??instruction insts (list (r1 line) (r2 line)))]
             [else           (??instruction insts (list (r1 line) (r2 line) (r3 line)))])))))

(define (bdf-structure R extension)
  (if (or (empty? extension) (andmap bv? (program-instructions R)))
      void
      (lambda (S)
        ; We enforce RIS constraints, which ensure that sketches with n
        ; added instructions use the last instruction.
        ; The last instruction is what distiguishes a BDF (n) sketch 
        ; from a BDF (n-1) sketch.
        (define prefix (first (isketch-index S)))
        (when (> prefix 0)
          (define last? (instruction->predicate (list-ref extension (- prefix 1))))
          (assert (ormap last? (program-instructions (isketch-program S))))))))

(define (bdf-subset R core extension cost-model)
  (define mincosts (sketch-mincosts R core extension cost-model))
  (lambda (c) (space mincosts (curry > c))))

; Given a reference program, core, extension, and cost model, 
; returns the minimum costs of all BDF sketches based on these arguments, 
; in the increasing index order. 
(define (sketch-mincosts R core extension cost-model)
  (define all (length (program-instructions R)))
  (define consts (count bv? (program-instructions R)))
  (define consts-cost (* consts (cost-model bv)))
  (cond 
    [(= consts all)
     (list consts-cost)]
    [else
     (define-values (inst-costs inst-mincosts) (ris-costs core extension cost-model))
     (define others (- all consts))
     (define others-1 (sub1 others))
     (for/list ([min-cost inst-mincosts]
                [last-cost inst-costs])
        (+ consts-cost (* others-1 min-cost) last-cost))]))

; An iteration space for the given association list of mincosts
; and the given cost filtering predicate.  
(struct space (mincosts acceptable-cost?)
  #:transparent
  #:property prop:sequence
  (lambda (self) (in-set self))
  #:methods gen:set
  [(define (set-count self) 
     (count (space-acceptable-cost? self) (space-mincosts self)))
   
   (define (set-member? self idx)
     (match-let ([(space mincosts acceptable-cost?) self]
                 [(list i) idx])
       (acceptable-cost? (list-ref mincosts i))))
   
   (define (in-set self)
     (match-define (space mincosts acceptable-cost?) self)
     (in-generator
      (for ([(c i) (in-indexed mincosts)] #:when (acceptable-cost? c))
        (yield (list i)))))])           
      
  
;(sketch-mincosts (program 1 (list (bv 3) (bvadd 1 2) (bv 4) (bvsub 3 4)))  (list bvsqrt bvadd) (list bvmul) sample-cost-model)
; (sketch-mincosts (program 1 (list (bv 3) (bv 4)))  (list bvsqrt bvadd) (list bvmul) sample-cost-model)
;(sketch-mincosts (program 1 (list (bv 3) (bvadd 1 2) (bv 4) (bvsub 3 4)))  (list bvsqrt bvmul) (list bvadd) sample-cost-model)
  
  


           
  