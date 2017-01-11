#lang s-exp rosette

(require racket/generic
  "iterator.rkt" "../engine/metasketch.rkt" "../engine/eval.rkt" "../engine/util.rkt")

(provide (rename-out [imeta-make imeta] [isketch-make isketch] [isketch-program-lazy isketch-program])
         imeta? isketch? isketch-index)

; Constructs an indexed metasketch M using the provided arguments:
;
; * arity : natural/c is the input arity of all programs in M.
;
; * ref : (listof natural/c) -> program? takes as input an index 
; (a list of natural numbers) and returns a symbolic program 
; (that is, a representation of a set of programs) at that index. 
; The programs returned by ref must take arity(M) arguments.
;
; * subset : (or/c natural/c +inf.0) -> set? takes as input a cost
; and returns a (possibly infinite) set of all indices idx such that 
; ref(idx) contains a program that is cheaper than the given cost. 
; It must be the case that subset(c) ⊆ {isketch-index(S) | S ∈ family(M)} 
; for all c, and it must be the case that subset(c) ⊆ subset(c') whenever c ≤ c'.
; Sets produced by the subset procedure must support membership testing 
; (via set-member?), iteration (via in-set), and cardinality (via set-count).
; 
; * pre : (listof number?) -> void? emits assertions on (symbolic)  
; inputs that represent preconditions for all programs in M.
;
; * post : program? ->  (listof number?) -> void? emits assertions that 
; constrain the output of all programs in M when applied to 
; (symbolic) inputs.
; 
; * structure : isketch? -> void? takes as input an indexed sketch from M and 
; emits assertions that hold for programs that are not equivalent---up to 
; simple syntactic transformations---to programs in lower-indexed sketches. 
;
; * cost : program? -> (listof number?) -> number? returns the cost of a 
; given program from M, when applied to the given (symbolic) inputs.
;
; * minbw: isketch? -> natural/c takes as input an indexed sketch from M 
; and returns the lower bound on the bitwidth necessary for synthesis.  In particular, 
; synthesizing the sketch with a lower bitwidth is guaranteed to return unsat.
(define (imeta-make #:arity arity
                    #:input-type [type integer?]
                    #:ref ref
                    #:subset subset
                    #:pre [pre void] 
                    #:post [post void]
                    #:structure structure
                    #:cost cost 
                    #:minbw minbw)
  ;(parameterize ([current-oracle (oracle)])
    (define-symbolic* in type [arity])
    (imeta ref subset in pre post structure cost minbw));)
  

; An indexed metasketch consists of a set of indexed sketches.  
; An indexed sketch is identified by an index, given as a list 
; of natural numbers, and it contains a symbolic representation 
; of a set of programs. 
(struct imeta
  (ref subset inputs pre post structure κ minbw)     
  
  #:methods gen:metasketch
  [(define (inputs self) (imeta-inputs self))
   
   (define (structure self S)
     (assertions (imeta-structure self) (list S)))
   
   (define (min-bitwidth self S)
     ((imeta-minbw self) S))
   
   (define (cost self P) 
     ((imeta-κ self) P (imeta-inputs self)))
   
   (define (sketches self [c +inf.0]) 
     (isketches self ((imeta-subset self) c)))])

(define (isketch-make meta index)
  (parameterize ([current-oracle (oracle)]) 
    (isketch meta index (imeta-pre meta) (imeta-post meta))))

; Wraps a set of indices to produce corresponding isketches on the fly.
(struct isketches (meta indices)
  #:transparent
  #:property prop:sequence
  (lambda (self) (in-set self))
  #:methods gen:set
  [(define/generic indices-set-count set-count)
   (define/generic indices-set-member? set-member?)
   (define/generic indices-in-set in-set)
   
   (define (set-count self) (indices-set-count (isketches-indices self)))
   
   (define (set-member? self S)
     (and (isketch? S) 
          (equal? (isketches-meta self) (isketch-meta S))
          (indices-set-member? (isketches-indices self) (isketch-index S))))
   
   (define (in-set self)
     (sequence-map (curry isketch-make (isketches-meta self)) 
                   (indices-in-set (isketches-indices self))))])

; An indexed sketch belongs to an indexed metasketch.  It 
; is identified by an index (a list of natural numbers), 
; and it contains a symbolic representation of a set of 
; programs.  In particular, a sketch is parameterized by 
; a set of holes (symbolic values), and every binding of 
; holes to values represents one program in the set of 
; programs defined by the sketch.
; An indexed sketch also carries pre- and post-conditions for
; programs contained in the sketch:
;   * pre : (listof number?) -> void? emits assertions on (symbolic)  
;     inputs that represent preconditions for all programs in M.
;   * post : program? ->  (listof number?) -> void? emits assertions that 
;     constrain the output of all programs in M when applied to 
;     (symbolic) inputs.
(struct isketch (meta index pre post [program #:auto]) #:mutable 
  
  #:methods gen:sketch
  [(define (metasketch self) (isketch-meta self))
   (define (programs self [sol (sat)])
      (if (zero? (dict-count (model sol)))
          (isketch-program-lazy self)
          (evaluate (isketch-program-lazy self) sol)))
   (define (pre self)
    (assertions (isketch-pre self) (list (imeta-inputs (isketch-meta self)))))
   (define (post self P)
    (assertions (isketch-post self) (list P (imeta-inputs (isketch-meta self)))))]
  
  #:methods gen:custom-write
  [(define (write-proc self port mode)
     (fprintf port "<~a, ~a>" (isketch-meta self) (isketch-index self)))]
  
  #:methods gen:equal+hash
  [(define (equal-proc s1 s2 =?) 
     (and (=? (isketch-meta s1) (isketch-meta s2))
          (=? (isketch-index s1) (isketch-index s2))))
   (define (hash-proc s1 hash-code)
      (hash-code (list (isketch-meta s1) (isketch-index s1))))
   (define (hash2-proc s1 hash-code)
      (hash-code (list (isketch-meta s1) (isketch-index s1))))])
  
(define (isketch-program-lazy S)
  (when (false? (isketch-program S))
    (set-isketch-program! S ((imeta-ref (isketch-meta S)) (isketch-index S))))
  (isketch-program S))
