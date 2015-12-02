#lang s-exp rosette

(require racket/cmdline
         "../parrot/least-squares.rkt"
         "../../opsyn/engine/search.rkt"
         "../../opsyn/engine/metasketch.rkt"
         "../../opsyn/metasketches/piecewise.rkt"
         "../../opsyn/bv/lang.rkt")

(current-subprocess-custodian-mode 'kill)  
(current-bitwidth 32)

(define verbose? (make-parameter #f))

(command-line
  #:program "least-squares"
  #:once-each
  ["-v"
   "Verbose output"
   (verbose? #t)])

; f(x) = x**3 - 8*x**2 + x - 9
; samples with gaussian noise (mean 0, stdev 5)
(define points (list
   '(-1 -12) '(-1 -20) '(-1 -10)
   '(0 -6) '(0 -7) '(0 -7)
   '(1 -13) '(1 -23) '(1 -18)
   '(2 -29) '(2 -36) '(2 -29)
   '(3 -51) '(3 -48) '(3 -59)
   '(4 -64) '(4 -64) '(4 -74)
   '(5 -76) '(5 -87) '(5 -79)
   '(6 -72) '(6 -76) '(6 -72)
   '(7 -48) '(7 -46) '(7 -50)
   '(8 4) '(8 3) '(8 -1)
   '(9 85) '(9 79) '(9 72)
   '(10 196) '(10 203) '(10 200)))

(define M `(least-squares-ms #:pieces 1
                             #:degree 3
                             #:points (list ,@(for/list ([io points]) `(list ,@io)))))

(printf "least-squares regression\n")
(printf "fitting to f(x) = x**3 - 8*x**2 + x - 9 with gaussian noise (σ = 5)\n")

(define P
  (search #:metasketch M
          #:threads 1
          #:timeout 3600
          #:bitwidth 32
          #:verbose (verbose?)))

; this output code only works for a single-piece polynomial
(define coeffs (piecewise-program-coefficients P))
(define piece (first coeffs))
(define terms 
  (for/list ([(c i) (in-indexed (drop piece 1))])
    (let ([c (first c)])
      (format "~ax**~a" (if (= c 1) "" (format "~a*" c))
                        (+ i 1)))))
(define const (first piece))
(printf "learned polynomial:\n")
(for ([t (reverse terms)])
  (printf "~a + " t))
(printf "~a\n" const)
