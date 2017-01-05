#lang s-exp rosette

(require "../bv/lang.rkt"
         "imetasketch.rkt"
         "iterator.rkt"
         racket/serialize)

(provide neural neural/search
         deserialize-info:neural-program
         (struct-out neural-program))


; Given an upper bound on the topology and a set of input-output-examples, 
; return a metasketch that represents neural networks 
; up to that topology, with the weights as holes.
; If classifier? is #t, the neural networks additionally train a decision
; threshold, and return 0 if the network output is below the threshold 
; or 1 otherwise.
(define (neural #:arity arity 
                #:maxlayers maxlayers
                #:maxnodes maxnodes
                #:classifier? [classifier? #t]
                #:data data)
  (define errfn (make-error-fn data))
  (neural/search #:arity arity
                 #:maxlayers maxlayers
                 #:maxnodes maxnodes
                 #:classifier? classifier?
                 #:cost errfn))

(define (neural/search #:arity arity
                       #:maxlayers maxlayers
                       #:maxnodes maxnodes
                       #:classifier? [classifier? #t]
                       #:pre [pre void]
                       #:post [post void]
                       #:cost cost)
  (imeta
    #:arity arity
    #:pre pre
    #:post (neural-post post classifier?)
    #:structure void
    #:cost cost
    #:ref (curry make-neural-program classifier?)
    #:subset (neural-subset arity maxlayers maxnodes)
    #:minbw (const 8)))


; Given a set of input-output examples, create an error function
; that takes as input a program P and list of symbolic inputs,
; and returns the sum of absolute errors on each example.
(define (make-error-fn data)
  (lambda (P inputs)
    (define diffs (for/list ([io data])
                    (abs (- (interpret P (car io)) (cdr io)))))
    (apply + diffs)))


; A neural program with n instructions serializes to a vector of length n+2:
; 0. arity
; 1. topology
; 2. weights
; 3 to n+3. instructions
(define deserialize-info:neural-program
  (make-deserialize-info
   (lambda e
     (neural-program
      (first e)
      (for/list ([op (drop e 3)])
        (deserialize op))
      (second e)
      (third e)))
   (const #f)))
(struct neural-program program (topology weights)
  #:transparent
  #:property prop:serializable
  (make-serialize-info
   (lambda (s)
     (vector-append
      (vector (program-inputs s)
              (neural-program-topology s)
              (neural-program-weights s))
      (for/vector ([op (program-instructions s)])
        (serialize op))))
   #'deserialize-info:neural-program
   #f
   (or (current-load-relative-directory) (current-directory))))


(define (neural-post post classifier?)
  (lambda (P inputs)
    (post P inputs)
    (when classifier?
      (define r (interpret P inputs))
      (assert (or (= r 0) (= r 1))))
    (for ([w (flatten (neural-program-weights P))])
      (assert (< w (expt 2 4)))
      (assert (< (- (expt 2 4)) w)))))


(define (neural-subset arity maxlayers maxnodes)
  (lambda (c)
    (cond 
      [(= c 0) (set)]
      [else
        (define topologies
          (let loop ([layers 1][topologies '()])
            (define t (sequence->list (enumerate-cross-product/z (for/list ([l layers]) maxnodes))))
            (define t* (map (lambda (x) `(,arity ,@(map add1 x) 1)) t))
            (set! topologies (append topologies t*))
            (cond [(< layers maxlayers) (loop (add1 layers) topologies)]
                  [else topologies])))
        (list->set topologies)])))


(define (make-const)
  (define-symbolic* val integer?)
  (values (bv val) val))

(define (make-neural-program classifier? topology)
  (unless (>= (length topology) 2)
    (error 'neural-program "topology must have at least two layers"))
  (define prog (list (bv 0)))  ; need a constant 0 for comparisons
  (define weights '())
  (define arity (first topology))
  (define zero arity)
  (for ([prev topology] [cur (cdr topology)] [l (length topology)])
    (define start (+ arity (length prog)))
    (define (w_ij i j)
      (+ start (* prev j) i))
    (define (x_i i)
      (if (= l 0)
          i
          (+ (- start (* 2 prev)) (* 2 i) 1)))
    ; make weights for this layer
    (define-values (consts vals)
      (for/lists (o v) ([j cur])
        (for/lists (oo vv) ([i prev])
          (make-const))))
    (set! weights (append weights (list vals)))
    (set! consts (flatten consts))
    ; make sums for each node
    (define sums (flatten
      (for/list ([j cur])
        (define s (+ start (length consts) (* j (- (* 2 prev) 1))))
        ; w_ij*x_i
        (define prods
          (for/list ([i prev])
            (bvmul (w_ij i j) (x_i i))))
        (define ops prods)
        ; ∑_i w_ij*x_i
        (when (> prev 1)
          (define first-sum (bvadd s (+ s 1)))
          (define ss (+ s prev -2))
          (define adds
            (for/list ([i (in-range 2 prev)])
              (bvadd (+ ss i) (+ s i))))
          (set! adds (append (list first-sum) adds))
          (set! ops (append ops adds)))
        ops)))
    ; make activations for each node
    (define idx (+ start (length consts) (length sums)))
    (define activs (flatten
      (for/list ([j cur])
        (define x_j (+ start (length consts) (* j (- (* 2 prev) 1)) (+ prev (- prev 2))))
        (list
         (bvslt x_j zero)
         (ite (+ idx (* 2 j)) zero x_j)))))
    (set! prog (append prog (append consts sums activs))))

  ; Force the neural network to return either 0 or 1, with a hole for the output
  ; threshold that determines which to return.
  (when classifier?
    (define-symbolic* threshold integer?)
    (define n (+ arity (length prog)))
    (define classifier (list (bv 0) (bv 1) (bv threshold) (bvslt (- n 1) (+ n 2)) (ite (+ n 3) n (+ n 1))))
    (set! prog (append prog classifier)))

  (neural-program arity prog topology weights))
