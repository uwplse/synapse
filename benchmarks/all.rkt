#lang racket

(require "../opsyn/metasketches/cost.rkt" "../opsyn/metasketches/iterator.rkt"
         "hd/reference.rkt" "hd/d0.rkt" "hd/d5.rkt" "hd/wcet.rkt"
         "parrot/specs.rkt"
         "parrot/sobel.rkt" "parrot/kmeans.rkt" "parrot/fft.rkt" "parrot/inversek2j.rkt"
         "parrot/least-squares.rkt"
         "arrays/arraysearch.rkt"
         "sygus/qm/reference.rkt"
         "demos/example.rkt"
         "../opsyn/metasketches/neural.rkt"
         "../opsyn/metasketches/stress-test.rkt")

(provide eval-metasketch)

(define-namespace-anchor a)
(define ns (namespace-anchor->namespace a))

(define (eval-metasketch ms)
  (eval ms ns))
  
