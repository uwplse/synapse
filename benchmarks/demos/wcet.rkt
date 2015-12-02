#lang s-exp rosette

(require racket/cmdline
         "../hd/wcet.rkt"
         "../../opsyn/engine/search.rkt"
         "../../opsyn/engine/metasketch.rkt"
         "../../opsyn/bv/lang.rkt")

(current-bitwidth 32)
(current-subprocess-custodian-mode 'kill)  

(define verbose? (make-parameter #f))

(command-line
  #:program "least-squares"
  #:once-each
  ["-v"
   "Verbose output"
   (verbose? #t)])

(define Mqstatic '(hd-sgn #:dynamic-cost? #f))
(define Mstatic (hd-sgn #:dynamic-cost? #f))
(define Mqdynamic '(hd-sgn #:dynamic-cost? #t))
(define Mdynamic (hd-sgn #:dynamic-cost? #t))

(printf "solving with static cost function...\n")
(define Pstatic
  (search #:metasketch Mqstatic
          #:threads 1
          #:timeout 3600
          #:bitwidth (current-bitwidth)
          #:verbose (verbose?)))

(printf "solving with dynamic cost function...\n")
(define Pdynamic
  (search #:metasketch Mqdynamic
          #:threads 1
          #:timeout 3600
          #:bitwidth (current-bitwidth)
          #:verbose (verbose?)))

(printf "P_static = ~s\n" Pstatic)
(printf "P_dynamic = ~s\n" Pdynamic)
(newline)
(printf "κ_static(P_static) = ~v\n" (cost Mstatic Pstatic))
(printf "κ_static(P_dynamic) = ~v\n" (cost Mstatic Pdynamic))
(printf "κ_dynamic(P_static) = ~v\n" (cost Mdynamic Pstatic))
(printf "κ_dynamic(P_dynamic) = ~v\n" (cost Mdynamic Pdynamic))
