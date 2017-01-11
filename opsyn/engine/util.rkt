#lang racket

(require (only-in rosette with-asserts-only current-bitwidth))

(provide assertions finitize thread-try-receive-all)

; Returns a list of all assertions emitted 
; when evaluating (apply proc input), if 
; the evaluation terminates normally.  
; Otherwise returns '(#f).
(define (assertions proc input)
  (with-handlers ([exn:fail? (const '(#f))]) 
    (with-asserts-only (apply proc input))))

; If the given value v is a concrete number, 
; returns its finitized representation, truncated
; to (current-bitwidth) bits.  Otherwse returns v.
(define (finitize v) 
  (match v
    [(? number? num) 
     (let* ([bitwidth (current-bitwidth)]
              [mask (arithmetic-shift -1 bitwidth)]
              [masked (bitwise-and (bitwise-not mask) (inexact->exact (floor num)))])
         (if (bitwise-bit-set? masked (- bitwidth 1))
             (bitwise-ior mask masked)  
             masked))]
    [_ v]))

; Receives and dequeues the list of all messages queued for the current thread, if any. 
; If no message is available, returns the empty list.
(define (thread-try-receive-all)
  (match (thread-try-receive)
    [#f null]
    [v (cons v (thread-try-receive-all))]))
