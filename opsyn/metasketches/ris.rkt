#lang s-exp rosette

(require
  racket/generator
  "imetasketch.rkt" "superoptimization.rkt" "cost.rkt" "order.rkt"
  "../engine/metasketch.rkt" "../engine/eval.rkt" "../engine/util.rkt"
  "../bv/lang.rkt" "../bv/hole.rkt" "../bv/lib.rkt")

(provide ris ris-costs)

; This procedure constructs a reduced instruction (RIS) metasketch 
; that represents a family of sketches for a subset of the BV language, 
; and for an additive cost function based on the given cost model.
; Each sketch in the family represents all programs of length k ∈ [1..) 
; that may contain any instruction from a core set of instructions, 
; extended with a prefix of length n of the remaining BV instructions.
; 
; The procedure constructs a metasketch M from the following inputs:
;
; * core : (listof instruction?) is the list of core instructions that 
; may appear in any program drawn from M.  The core list must be non-empty.  
;
; * extension : (listof (or/c unary? binary? ternary?)) is the 
; list of additional instructions that may appear in a program drawn from M.  
; Extension instructions must be different from the core instructions.
;
; * arity : natural-number/c is the input arity of all programs in M.
;
; * maxlength :  (or/c natural-number/c +inf.0) is a number specifiying 
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
;
; * order : (or/c #f ((listof number?) . -> . sequence?)) is a procedure
; that, given the bounds of an index space, produces a sequence that is a
; search order for that space. If #f, a default search order is used.
(define (ris #:core core 
             #:extension extension
             #:maxlength [maxlength +inf.0]
             #:arity arity   
             #:pre [pre void] 
             #:post [post void]
             #:cost-model [cost-model sample-cost-model]
             #:order [order #f])
  (check-max-length 'ris maxlength)
  (imeta 
   #:arity arity
   #:subset (ris-subset (+ maxlength 1) core extension cost-model order)
   #:pre pre
   #:post post
   #:structure (ris-structure extension)
   #:cost (∑cost cost-model)
   #:ref  (lambda (idx) (??program arity (first idx) (append core (take extension (second idx)))))
   #:minbw (const 16)))

; Returns two lists of size |extension| + 1. The first 
; list, L1, has (lowest-cost core cost-model) as its car and
; the costs of extension instructions as its cdr.  The 
; second list, L2, has (apply min (take L1 (+ i 1))) 
; in the ith position.
(define (ris-costs core extension cost-model)
  (define costs (cons (lowest-cost core cost-model) (map cost-model extension)))
  (define mincosts
    (let loop ([costs (cdr costs)][current-min (car costs)][out (list (car costs))])
      (match costs
        [(list) (reverse out)]
        [(list x xs ...) 
         (let ([next-min (min x current-min)])
           (loop xs next-min (cons next-min out)))])))
  (values costs mincosts))

(define (ris-subset end core extension cost-model order)
  (define-values (costs mincosts) (ris-costs core extension cost-model))
  (define cheapest (apply min mincosts))
  (define max-width (+ (length extension) 1))
  (lambda (c)
    (define len (min end (max 1 (ceiling (/ c cheapest)))))
    (define width (lambda (l) ; at least one instruction must be the ith extension instruction for a program of length l
                    (for/list ([(mincost i) (in-indexed mincosts)]
                               [last-cost costs] 
                               #:when (< (+ last-cost (* mincost (- l 1))) c)) 
                      i)))
    (if (false? order)
        (space len width)
        (ordered-space (space len width) (order (list len max-width))))))

; An iteration space for the given exclusive upper bound on program length. 
; The width : natural/c -> (listof natural-number/c)
; takes as input a program length and returns the list of valid 
; indices for that program length.
(struct space (length width)
  #:transparent
  #:property prop:sequence
  (lambda (self) (in-set self))
  #:methods gen:set
  [(define (set-count self) 
     (match-define (space L W) self)
     (if (infinite? L) 
         L 
         (for/sum ([idx (in-range 1 L)]) (length (W idx)))))
   
   (define (set-member? self idx)
     (match-let ([(space L W) self]
                 [(list l w) idx])
       (and (<= 1 l) (< l L) (member w (W l)) #t)))
   
   (define (in-set self)
     (match-define (space L W) self)
     (in-generator
      (for* ([l (in-range 1 L)][w (W l)])
        (yield (list l w)))))])
      
(define (ris-structure extension)
  (lambda (S)
    ; We enforce the superoptimization constraints, 
    ; which ensure that sketches of length k use all k slots.
    (superopt-structure S)
    ; We enforce RIS constraints, which ensure that sketches of 
    ; length k and with n instructions use the last instruction.
    ; The last instruction is what distiguishes a RIS (k n) sketch 
    ; from a RIS (k n-1) sketch.
    (define prefix (second (isketch-index S)))
    (when (> prefix 0)
      (define last? (instruction->predicate (list-ref extension (- prefix 1))))
      (assert (ormap last? (program-instructions (isketch-program S)))))))




  
   
               
  
           
              

