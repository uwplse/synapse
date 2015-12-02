#lang racket

(require "util.rkt"
         rosette/query/state 
         rosette/base/term 
         (only-in rosette >> << >>> current-bitwidth)
         rosette/base/generic rosette/base/union
         rosette/base/merge rosette/solver/solution)

(provide evaluate)

; Partially evaluates the given expression with respect to the provided solution and 
; returns the result.  In particular, if the solution has a binding for every symbolic 
; variable occuring in the expression, the output is a concrete value.  Otherwise, the 
; output is a (possibly) symbolic value, expressed in terms of variables that are not
; bound by the given solution.  The solution must be sat?.
(define (evaluate expr [sol (current-solution)])
  (if (and (sat? sol) (= (dict-count (model sol)) 0)) 
      expr
      (eval-rec expr sol (make-hash))))

(define (eval-rec expr sol cache)
  (if (hash-has-key? cache expr) 
      (hash-ref cache expr)
      (let ([result
             (match expr
               [(? constant?)            
                (sol expr)]
               [(expression (== ite) b t f) 
                (match (eval-rec b sol cache)
                  [#t (eval-rec t sol cache)]
                  [#f (eval-rec f sol cache)]
                  [g (ite g (eval-rec t sol cache) (eval-rec f sol cache))])]
               [(expression (and (or (== >>) (== >>>) (== <<)) op) left right)
                (let* ([shift (finitize (eval-rec right sol cache))]
                       [shift (if (number? shift) (min shift (current-bitwidth)) shift)]
                       [shift (if (number? shift) (if (>= shift 0) shift (current-bitwidth)) shift)])
                (finitize (op (finitize (eval-rec left sol cache)) shift)))]
               [(expression op child ...)  
                (finitize (apply op (for/list ([e child]) (finitize (eval-rec e sol cache)))))]
               [(? list?)                
                (for/list ([e expr]) (eval-rec e sol cache))]
               [(cons x y)               
                (cons (eval-rec x sol cache) (eval-rec y sol cache))]
               [(? vector?)              
                (for/vector #:length (vector-length expr) ([e expr]) (eval-rec e sol cache))]
               [(union vs)                 
                (let loop ([vs vs] [out '()])
                  (if (null? vs) 
                      (apply merge* out)
                      (let ([gv (car vs)])
                        (match (eval-rec (car gv) sol cache)
                          [#t (eval-rec (cdr gv) sol cache)]
                          [#f (loop (cdr vs) out)]
                          [g  (loop (cdr vs) (cons (cons g (eval-rec (cdr gv) sol cache)) out))]))))]
               [(? typed?)              
                (let ([t (get-type expr)])
                  (match (type-deconstruct t expr)
                    [(list (== expr)) expr]
                    [vs (type-construct t (for/list ([v vs]) (eval-rec v sol cache)))]))]
               [_ expr])])
        (hash-set! cache expr result)
        result)))
