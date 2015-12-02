#lang s-exp rosette

(require "../../../opsyn/metasketches/neural.rkt"
         "../../../opsyn/engine/search.rkt"
         "../../../opsyn/bv/lang.rkt"
         racket/cmdline
         "data.rkt")

(current-subprocess-custodian-mode 'kill)
(current-bitwidth 8)

(define verbose? (make-parameter #f))

(command-line
  #:program "cats"
  #:once-each
  ["-v"
   "Verbose output"
   (verbose? #t)])

(define num-examples 20)
(define data (append (for/list ([c cats][i num-examples]) (cons c 1))
                     (for/list ([a airplanes][i num-examples]) (cons a 0))))

(define M
  `(neural 
     #:arity 64 #:maxlayers 2 #:maxnodes 4
     #:data (list ,@(for/list ([io data]) `(cons (list ,@(car io)) ,(cdr io))))))

(define sol (search #:metasketch M
                    #:threads 1
                    #:timeout 3600
                    #:bitwidth (current-bitwidth)
                    #:verbose (verbose?)))

(printf "learned a neural network with topology ~a\n" (neural-program-topology sol))

(for ([c cats][i num-examples])
  (printf "cat ~s: ~s\n" i (interpret sol c)))
(for ([a airplanes][i num-examples])
  (printf "ap ~s: ~s\n" i (interpret sol a)))
