#lang s-exp rosette

(require "../../opsyn/metasketches/neural.rkt"
         "../../opsyn/engine/search.rkt"
         "../../opsyn/bv/lang.rkt"
         racket/cmdline)

(current-subprocess-custodian-mode 'kill)
(current-bitwidth 32)

(define verbose? (make-parameter #f))

(command-line
  #:program "neural"
  #:once-each
  ["-v"
   "Verbose output"
   (verbose? #t)])

(define points '(((1 1) . 0)  ; XOR function
                 ((1 0) . 1)
                 ((0 1) . 1)
                 ((0 0) . 0)))

(define Mxor
  `(neural 
     #:arity 2 #:maxlayers 2 #:maxnodes 2 #:classifier? #f
     #:data (list ,@(for/list ([io points]) `(cons (list ,@(car io)) ,(cdr io))))))

(define sol (search #:metasketch Mxor
                    #:threads 1
                    #:timeout 3600
                    #:bitwidth (current-bitwidth)
                    #:verbose (verbose?)))

(printf "learned a neural network with topology ~s:\n" (neural-program-topology sol))
(for* ([x 2][y 2])
  (printf "~a ^ ~a = ~a\n" x y (interpret sol (list x y))))
