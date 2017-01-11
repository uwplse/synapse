#lang racket

(require "eval.rkt" "util.rkt" "log.rkt"
         (only-in rosette/base/core/bitvector bitvector [bv rosette-bv])
         (only-in rosette/base/core/bool @boolean? ! ||) 
         (only-in rosette/base/core/real @integer? @real?)
         (only-in rosette symbolics type-of constant term? union? current-bitwidth)
         rosette/solver/solver rosette/solver/smt/z3
         rosette/solver/solution)

(provide ∃∀solver)

; This procedure implements an asynchronous incremental solver for 
; problems of the form ∃hs. ∀xs. Pre(xs) ⇒ Post(xs, hs), where 
; * xs is a list of symbolic constants; 
; * Pre(xs) and Post(xs, hs) stand for conjunctions of boolean values in the lists 
;   pre and post, respectively; 
; * samples is a list of sample points (satisfiable solutions) drawn from the domain
;   of xs that all satisfy Pre(xs); and
; * output is the thread that will consume solutions produced by this incremental  
;   synthesizer.  
; 
; Given these inputs, the procedure returns a thread T that will accept constraints 
; and samples through its mailbox, and that will produce solutions to the consumer 
; thread's mailbox. 
;
; The thread T accepts two kinds of messages:  lists of constraints (boolean values) and 
; lists of samples (satisfiable solutions for xs that satisfy Pre(xs)).  In response to 
; these messages, it outputs lists of the form (T S I), where S is a discovered solution and 
; I is the list of samples used to arrive at that solution.  The thread T will continue 
; outputing results as long as it is receiving new post-conditions through its mailbox, and 
; as long as those post-conditions are satisfiable.  Once it outputs an unsatisfiable solution, 
; T will terminate.
;
; More formally, let P be the sequence of all postconditions received by T.  
; Let S be a satisfiable solution emitted by T.  Then, there is some index idx(S)  
; such that S is a solution to the problem 
; ∃hs. ∀xs. Pre(xs) ⇒ (Post(xs, hs) ∧ P[0] ∧ ... ∧ P[idx(S)-1]).
; Moreover, if T emits two satisfiable solutions Sk and Sn such that k < n, then 
; then idx(Sk) < idx(Sn).  If T emits an unsatisfiable solution, then no 
; other solutions are ever emitted, and there is a prefix of P that is unsatisfiable.
; 
; The thread T may use external resources (processes).  To ensure that they are properly 
; released,  T should be shut down via custodian-shutdown-all, with 
; current-subprocess-custodian-mode set to 'kill.
(define (∃∀solver 
         #:forall  [inputs '()]
         #:pre     [pre '()]
         #:post    [post '()]
         #:samples [samples '()]
         #:output  [output (current-thread)])                  ; Type of solver to use for verification.  
  (thread
   (thunk
    ;(parameterize ([ignore-division-by-0 #t])
      (send (new ∃∀solver% 
                 [inputs inputs] [pre pre] [output output])
            solve post samples))));)

(define ∃∀solver%
  (class* object% ()
    
    ;-------- constructor -------- ; 
    (init-field
     inputs     ; xs
     pre        ; Pre(xs)
     output)    ; consumer thread
       
    ;-------- initialization -------- ; 

    ; free-symbols(pre) ⊆ inputs
    (unless (for/and ([c (symbolics pre)]) (member c inputs))
      (raise-arguments-error '∃∀solver "preconditions may only reference input symbols"))
    
    (define-values (synthesizer verifier) (values (z3) (z3)))
       
    (define-values (post samples pool hole-vars) 
      (values '() '() '() '()))

    (define trial -1)

    (super-new)
   
    
    ;-------- public interface -------- ; 
    
    ; Starts the solving process.
    (define/public (solve post+ samples+)
      (initialize samples+)
      
      (let loop ([post+ post+] [samples+ '()])
        (set! trial (add1 trial))
        (add-samples-to-pool! samples+)
        (add-hole-vars! (symbolics (append post+ post)))
        (define-values (dynamic static) (partition input-dependent? post+))
        
        (unless (empty? dynamic)
          (set! post (append post dynamic))
          (for ([sample samples])
            (solver-assert synthesizer (evaluate dynamic sample))))
        
        (unless (empty? static)
          (solver-assert synthesizer static))

        (log-cegis [trial] "searching for a candidate solution...")

        (define synth-start-time (current-inexact-milliseconds))
        (define candidate (solver-check synthesizer))
        
        (cond
          [(sat? candidate)
           (log-cegis [trial] [synth-start-time] "verifying the candidate solution...")
           (define verify-start-time (current-inexact-milliseconds))
           (define cex (verify candidate))
           (cond 
             [(sat? cex)
              (set! cex (model->sample cex))
              (log-cegis [trial] [verify-start-time] "solution falsified by ~s" (map cex inputs))
              (solver-assert synthesizer (evaluate post cex))
              (set! samples `(,@samples ,cex))
              (call-with-values thread-receive-non-blocking loop)]
             [else ; we have a valid candidate
              (log-cegis [trial] [verify-start-time] "solution verified")
              (define result (concretize candidate hole-vars))
              (thread-send output (list (current-thread) result samples))
              (call-with-values thread-receive-blocking loop)])]
          [else    ; we are done
           (log-cegis [trial] [synth-start-time] "no solutions")
           (cleanup)
           (thread-send output (list (current-thread) candidate samples))])))
    
    ;-------- private functions -------- ; 
    (define (cleanup)
      (when synthesizer 
        (solver-shutdown synthesizer) 
        (set! synthesizer #f))
      (when verifier 
        (solver-shutdown verifier)
        (set! verifier #f)))
    
    ; Initializes the sample pool if needed
    (define (initialize points)
      (add-samples-to-pool! points)
      (cond 
        [(empty? pool)
         (solver-assert verifier pre)
         (define s (solver-check verifier))
         (solver-clear verifier)
         (when (sat? s)
           (set! samples (list (model->sample s))))]
        [else
         (set! samples (cons (car pool) samples))
         (set! pool (cdr pool))]))
    
    ; Returns true if the given value is a postcondition (rather than a solution).
    (define (postcondition? v) (not (solution? v)))
    
    ; Returns all constraints and samples from this thread's mailbox without blocking.
    (define (thread-receive-non-blocking)
      (partition postcondition? (flatten (thread-try-receive-all))))
    
    ; Returns all constraints and sample from this thread's mailbox, blocking until 
    ; it receives at least one constraint.
    (define (thread-receive-blocking)
      (match (thread-receive)
        [(and post+ (list (? postcondition?) _ ...))
         (define-values (constrs points) (thread-receive-non-blocking))
         (values (append post+ constrs) points)]
        [points+
         (define-values (constrs points) (thread-receive-blocking))
         (values constrs (append points+ points))]))

    (define (add-hole-vars! vars)
      (for ([var vars])
        (unless (member var inputs)
          (set! hole-vars (cons var hole-vars))))

      (set! hole-vars (remove-duplicates hole-vars)))
    
    ; Verifies the given candidate solution, producing unsat if the candidate 
    ; is correct or a counterexample otherwise.
    (define (verify candidate)
      (define ¬asserts (apply || (map ! (evaluate post candidate))))
      (or (for/first ([p pool] #:when (evaluate ¬asserts p))
            (log-cegis [trial] "candidate failed existing testcase ~s" (map p inputs))
            (set! pool (remove p pool))
            p)
          (begin
            (solver-assert verifier pre)
            (solver-assert verifier (list ¬asserts))
            (begin0
              (solver-check verifier)
              (solver-clear verifier)))))
    
    ; Adds the given sample points to the pool of samples. 
    ; Raises an error if any of the given point is not a sample for
    ; the given inputs and preconditions. 
    (define (add-samples-to-pool! points)
      (unless (empty? points)
        (for ([p points] #:unless (sample? p))
          (raise-arguments-error 
           '∃∀solver 
           "a sample point must be a model for preconditions over the input symbols" "point" p))
        (set! pool (remove-duplicates (append pool points) sample=?))))
    
    ; Returns true iff any input constants 
    ; occur freely in the given constraint.
    (define (input-dependent? constr)
      (for/or ([sym (symbolics constr)])
        (member sym inputs)))
    
    ; Pads the given satisfiable solution with default values so that 
    ; each input is bound to a concrete value.
    (define (model->sample m)
      (concretize m inputs))

    ; Pads the given satisfiable solution with default values so that 
    ; each variable is bound to a concrete value.
    (define (concretize m variables)
      (sat (for/hash ([in variables]) 
             (match (m in)
               [(constant _ (bitvector bw))
                (values in (rosette-bv 0 (bitvector bw)))]
               [(constant _ (== @integer?))
                (values in 0)]
               [(constant _ (== @real?))
                (values in 0)]
               [(constant _ (== @boolean?))
                (values in #f)]
               [val (values in val)]))))

    ; Returns true iff p is a satisfiable solution 
    ; that binds inputs to concrete values 
    ; and that satisfies the preconditions.
    (define (sample? p)
      (and (solution? p) 
           (sat? p)
           (let ([m (model p)])
             (and (= (length inputs) (dict-count m))
                  (for/and ([x inputs]) (dict-has-key? m x))
                  (for/and ([v (in-dict-values m)]) (not (or (term? v) (union? v))))
                  (for/and ([constraint pre]) (equal? #t (evaluate constraint p)))))))  
    
    ; Returns true iff the given satisfiable solutions 
    ; bind the same symbolic constants to the same values.
    (define (sample=? s1 s2)
      (equal? (model s1) (model s2)))))
