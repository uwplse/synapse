#lang s-exp rosette

(require
  "imetasketch.rkt" "cost.rkt" 
  "../engine/metasketch.rkt" "../engine/eval.rkt" "../engine/util.rkt"
  "../bv/lang.rkt" "../bv/hole.rkt")

(provide superopt∑ make-superopt-minbw superopt-structure check-max-length)

; This procedure constructs a superoptimization metasketch 
; that represents a family of sketches for a subset of the BV language,
; and for an additive cost function based on the given cost model.
; Each sketch in the family represents all programs of length k ∈ [1..) 
; that may contain any instruction from the given subset of 
; BV in any position.
; 
; The procedure constructs a metasketch M from the following inputs:
;
; * instructions : (listof instruction?) is the list of instructions 
; that may appear in a program drawn from M.
;
; * arity : natural-number/c is the input arity of all programs in M.
;
; * maxlength : (or/c natural-number/c +inf.0) is a number specifiying 
; the length of the longest program in M. If the length is unbounded, 
; then maxlength should be +inf.0.  Otherwise, the length should be a
; positive natural number.
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
(define (superopt∑ 
         #:instructions insts 
         #:maxlength [maxlength +inf.0]
         #:arity arity
         #:input-type [type integer?]
         #:pre [pre void] 
         #:post [post void]
         #:cost-model [cost-model sample-cost-model])
  (check-max-length 'superopt∑ maxlength)
  (imeta 
   #:arity arity
   #:input-type type
   #:ref (lambda (idx) (??program arity (car idx) insts))
   #:subset (superopt-subset (+ 1 maxlength) insts cost-model)
   #:pre pre
   #:post post
   #:structure superopt-structure
   #:cost (∑cost cost-model)
   #:minbw (make-superopt-minbw arity)))

(define (check-max-length caller maxlength)
  (unless (or (= maxlength +inf.0) (and (positive? maxlength) (integer? maxlength)))
    (raise-arguments-error caller "expected a positive integer or +inf.0" "maxlength" maxlength)))

(define (make-superopt-minbw arity)
  (lambda (S)
    (max 6 (+ 1 (integer-length (+ arity (car (isketch-index S))))))))

(define (superopt-structure S)
  (define P (isketch-program S))
  (break-commutativity-symmetries P)
  (define insts (program-instructions P))
  (let loop ([insts insts] [reg (program-inputs P)])
    (unless (< (length insts) 2)
      (define rest (cdr insts))
      (assert (used? reg rest))
      (loop rest (add1 reg)))))

(define (superopt-subset end insts cost-model) 
  (define cheapest (lowest-cost insts cost-model))
  (lambda (c)  
    (space 1 (min end (max 1 (ceiling (/ c cheapest)))))))

; Represents a possibly infinite set of one-dimensional indices 
; (lists of natural numbers) in range [start..end).
; @invariant start ∈ natural-number/c
; @invariant end ∈ (or/c natural-number/c +inf.0)
; @invariant start <= end
(struct space (start end)
  #:transparent
  #:guard 
  (lambda (start end name)
    (unless (and (natural-number/c start) 
                 (or (natural-number/c end) (= +inf.0 end))
                  (<= start end))
      (raise-arguments-error name "not a valid start and end ranges" "start" start "end" end))
    (values start end))
  #:property prop:sequence
  (lambda (self) (in-set self))
  #:methods gen:set
  [(define (set-count self) 
     (match self [(space start end) (- end start)]))
   
   (define (set-member? self idx)
     (match-let ([(space start end) self]
                 [(list i) idx])
       (and (<= start i) (< i end))))
   
   (define (in-set self)
     (sequence-map 
      list
      (match self [(space start end) (in-range start end)])))])

  
   
               
  
           
              

