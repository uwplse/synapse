#lang racket

(require racket/generic)

(provide (all-defined-out))

; A metasketch encapsulates a set of sketches, and provides 
; functions for operating those sketches.  The set may be finite 
; or countably infinite.   A sketch itself is a function that  
; maps a list of parameters, called "holes", to a program 
; in a language L.
;
; A metasketch provides the following functions for operating on sketches: 
; * The cost function κ associates each program that corresponds to a sketch 
; with a natural number.  
; * The iteration function ι takes as input a natural number c and returns all 
; sketches in a given family that contain at least one program P with κ(P) < c.  
; The number of such sketches must be finite for every c.
; 
; @specfield arity : [1..)
; @specfield inputs : [0..arity) lone→one constant?
; @specfield family : set sketch
; @specifeld κ : (family.programs × inputs) →one [0..)
; @specfield ι : [0..) one→lone family
(define-generics metasketch
  
  ; Returns a list of distinct symbolic values that represent inputs to 
  ; the programs represented by this family of sketches.
  ; @return inputs
  (inputs metasketch)
  
  ; Given a sketch from this metasketch, returns a list of constraints 
  ; on its structure.  These constraints are defined over the holes of the sketch, 
  ; and may not refer to the input constants.  They impose additional restrictions  
  ; on the search space, by eliminating certain kinds of syntactic equivalences 
  ; (for example, equivalences due to dead code elimination or constant propagation).
  ; In particular, the space constraints S will exclude a program P from S only if 
  ; there is another sketch S' in this metasketch that includes a program P', where 
  ; P and P' are equivalent up to a simple syntactic transformation.
  ; @requires S ∈ family
  (structure metasketch S)
  
  ; Returns a minimum bitwidth necessary (but not sufficient) for solving the given 
  ; sketch from this metasketch.  In particular, using a smaller bitwidth is guaranteed 
  ; to result in no solution.
  (min-bitwidth metasketch S)
  
  ; Given a program from this metasketch, returns the cost of that program.
  ; If the cost of the program depends on the inputs, then the result is 
  ; a symbolic representation of the cost in which the input constants, 
  ; obtained by (send this inputs), appear as free symbols.  The resulting 
  ; number can be evaluated with respect to a solution that binds the input 
  ; symbols in order to obtain the cost for a given input.
  ; @requires ∃ sketch ∈ family. P ∈ sketch 
  ; @return cost(P, inputs)
  (cost metasketch P) 
  
  ; Given a natural number c or +inf.0, returns the set of all sketches in 
  ; this family that contain a program with a cost lower than c.  The resulting 
  ; set implementation supports membership testing (via set-member?), iteration 
  ; (via in-set), cardinality (via set-count), and emptyness testing (via set-empty?).
  ; @requires c ∈ [0..)
  ; @return { S : family | ∃ P ∈ S . cost(P, inputs) < c }
  (sketches metasketch [c]))


; A sketch represents a set of programs.  It is equipped with a function that  
; maps a list of parameters, called "holes", to a program in a language L.  A 
; sketch belongs to a given metasketches, and two sketches are equal iff they 
; both belong to the same metasketch and they represent the same set of programs.
; 
; @specfield metasketch: metasketch
; @specfield programs: set L
; @specfield holes: set constant?
; @specfield index: (and/c solution? sat?) → programs 
(define-generics sketch
  
  ; Returns the metasketch for this sketch.
  ; @return metasketch
  (metasketch sketch)
  
  ; Given a satisfiable solution? that maps holes to values, returns the program 
  ; from this sketch that is selected by the given hole assignment.  If one or more 
  ; holes are unassigned, the resulting program is a symbolic representation of a 
  ; subset of programs in this sketch.  
  ; 
  ; The solution argument is optional.  The default value is the empty solution, which 
  ; maps each hole in this sketch to itself.  The resulting symbolic program corresponds 
  ; to all programs represented by this sketch.
  ;
  ; If the solution argument is provided, the returned program must be serializable
  ; using racket/serialize.
  ;
  ; @requires (solution? sol) ∧ (sat? sol)
  ; @return index(sol)
  (programs sketch [sol])
  
  ; Returns a list of constraints that represent preconditions on the 
  ; inputs to the programs represented by this sketch.  The 
  ; only free symbols in these constraints will be drawn from the inputs 
  ; constants obtained by (send (send this metasketch) inputs). 
  ; This method always generates 
  ; fresh constraints that are finitized with respect to current-bitwidth.
  (pre sketch)
  
  ; Given a program from this sketch, returns a list of constraints 
  ; that represent postconditions on that program, with respect to the 
  ; inputs constants obtained by (send (send this metasketch) inputs).  
  ; This method always generates 
  ; fresh constraints that are finitized with respect to current-bitwidth.
  ; @requires P ∈ programs
  (post sketch P)
  )
