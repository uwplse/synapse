#lang s-exp rosette

(require "../opsyn/engine/solver+.rkt" "../opsyn/engine/verifier.rkt" "util.rkt" "../opsyn/engine/eval.rkt"
         rackunit "test-runner.rkt" (only-in racket remove*))

(current-bitwidth 32)
(define-symbolic x h integer?)
(define-symbolic ch1 ch2 boolean?)

(define (result=? actual expected)
  (match expected
    [(list (? thread? T) (? solution? S) (and I (list (? solution?) ...)))
     (match actual
       [(list (== T) (== S solution=?) (== I (lambda (I J) (andmap solution=? I J)))) 
        #t]
       [_ #f])]))

(define (result-solution=? actual expected)
  (match expected
    [(? solution? S)
     (match actual
       [(list _ (== S solution=?) _)
        #t]
       [_ #f])]))

; Trivial tests with no inputs, several #t constraints, several 
; solutions, and a #f constraint.
(define (test0)
  (test-case "trivial tests"
    (parameterize ([current-custodian (make-custodian)])
      (after
        (define T (∃∀solver))
        (check result=? (thread-receive) (list T (sat (hash)) (list (sat (hash)))))
        (thread-send T (list (sat (hash))))     
        (thread-send T (list (sat (hash)) (sat (hash))))     
        (thread-send T (list #t))  
        (check result=? (thread-receive) (list T (sat (hash)) (list (sat (hash)))))          
        (thread-send T (list #f))  
        (check result=? (thread-receive) (list T (unsat) (list (sat (hash)))))
        (check-true (thread-dead? T))
        (custodian-shutdown-all (current-custodian))))))
      
; Tests for x * 2 = x << ?? with samples 1, 2.
(define (test1)
  (test-case "x * 2 = x << ?? with samples 1, 2"
    (parameterize ([current-custodian (make-custodian)])
      (after
        (define T (∃∀solver #:forall (list x) 
                            #:post (list (= (* x 2) (<< x h))) 
                            #:samples (list (sat (hash x 1)) (sat (hash x 2)))))
        (check result=? (thread-receive) (list T (sat (hash h 1)) (list (sat (hash x 1)))))
        (thread-send T (list (sat (hash x 3))))
        (thread-send T (list (< h 1)))
        (check result=? (thread-receive) (list T (unsat) (list (sat (hash x 1)))))
        (check-true (thread-dead? T))
        (custodian-shutdown-all (current-custodian))))))

; Tests for x * 3 = x << ??.
(define (test2)
  (test-case "x * 3 = x << ??"
    (parameterize ([current-custodian (make-custodian)])
      (after
        (define T (∃∀solver #:forall (list x)))
        (thread-send T (list (= (* x 3) (<< x h))))
        (check solution=? (second (thread-receive)) (empty-solution))
        (check solution=? (second (thread-receive)) (unsat))
        (check-true (thread-dead? T))
        (custodian-shutdown-all (current-custodian))))))
  
; Tests for #f => (x * 3 = x << ??).
(define (test3)
  (test-case "#f => (x * 3 = x << ??)"
    (parameterize ([current-custodian (make-custodian)])
      (after
        (define T (∃∀solver #:forall (list x) #:pre (list #f) #:post (list (= (* x 3) (<< x h)))))
        (define ans (thread-receive))
        (check-true (sat? (second ans)))
        (check-true (empty? (third ans)))
        (thread-send T (list #t))
        (check result=? (thread-receive) ans)
        (thread-send T (list (< h 1)))
        (check-true (sat? (second (thread-receive))))
        (custodian-shutdown-all (current-custodian))))))

; Tests for x * 2 = x << ??, where inputs must be constructed 
; in such a way that the solver is forced to use all of them.
(define (test_x*2=x<<?? samples)
  (parameterize ([current-custodian (make-custodian)])
    (after
      (define T (∃∀solver #:forall (list x) #:post (list (= (* x 2) (<< x h))) #:samples samples))
      (define ans (thread-receive))
      (check result=? ans (list T (sat (hash h 1)) samples))
      (thread-send T (list (< h 1)))
      (check result=? (thread-receive) (list T (unsat) samples))
      (custodian-shutdown-all (current-custodian)))))

; Tests for x * 2 = x << ?? with input 1.
(define (test4)
  (test-case "x * 2 = x << ?? with input 1"
    (test_x*2=x<<?? (list (sat (hash x 1))))))

; Tests for x * 2 = x << ?? with inputs 0, 1.
(define (test5)
  (test-case "x * 2 = x << ?? with inputs 0, 1"
    (test_x*2=x<<?? (list (sat (hash x 0)) (sat (hash x 1))))))

; Tests for x * 2 = choose(x << ??, x + x) with input 1.
(define (test6)
  (test-case "x * 2 = choose(x << ??, x + x) with input 1"
    (parameterize ([current-custodian (make-custodian)])
      (after
        (define T  (∃∀solver #:forall (list x) 
                             #:post (list (= (* x 2) (if ch1 (<< x h) (+ x x)))) 
                             #:samples (list (sat (hash x 1)))))
        (define m1 (second (thread-receive)))
        (check-true (sat? m1))
        (thread-send T (list (equal? ch1 (not (m1 ch1)))))
        (define m2 (second (thread-receive)))
        (check-true (sat? m2))
        (check-false (equal? (m1 ch1) (m2 ch1)))
        (custodian-shutdown-all (current-custodian))))))

; Tests for x * 2 = if x < h then x << 1 else x + x with input 1.
(define (test7)
  (test-case "x * 2 = if x < h then x << 1 else x + x with input 1"
    (parameterize ([current-custodian (make-custodian)])
      (after
        (define T (∃∀solver #:forall (list x) 
                            #:post (list (= (* x 2) (if (< x 0) 
                                                        (if ch1 (<< x h) (+ x x)) 
                                                        (if ch2 (<< x h) (+ x x)))))
                            #:samples  (list (sat (hash x 1)))))
        (define m1 (second (thread-receive)))
        (check-true (sat? m1))
        (thread-send T (list (not (equal? ch1 ch2))))
        (define m2 (second (thread-receive)))
        (check-true (sat? m2))
        (check-false (equal? (m2 ch1) (m2 ch2)))
        (thread-send T (list (=> (< x 0) (equal? ch1 (not (m2 ch1))))))
        (define m3 (second (thread-receive)))
        (printf "M3: ~a\n" m3)
        (printf "output: ~a\n" (current-output-port))
        (check-true (sat? m3))
        (check-false (equal? (m2 ch1) (m3 ch1)))
        (custodian-shutdown-all (current-custodian))))))

; Test invariant maintenance.
(define (test8)
  (test-case "invariant maintenance"
    (parameterize ([current-custodian (make-custodian)]
                   [current-bitwidth 32])
      (after
        (define T (∃∀solver #:forall (list x) 
                                    #:pre (list (even? x))
                                    #:post (list (odd? (+ x h)))))
        (check result=? (thread-receive) (list T (sat (hash h 1)) (list (sat (hash x 0)))))
        (thread-send T (list (sat (hash x 2))))
        (thread-send T (list (sat (hash x 4))))
        (define posts (list (> h 16) (> h 14) (< h 18))) 
        (for ([p posts])
          (thread-send T (list p)))
        (define sol #f)
        (let loop ()      
          (unless (empty? posts)  
            (match (sync (thread-receive-evt)  (alarm-evt (+ (current-inexact-milliseconds) 10000)))
              [(== (thread-receive-evt))
               (set! sol (second (thread-receive)))
               (define solved (for/list ([p posts] #:when (evaluate p sol)) p))
               (check-false (empty? solved))
               (set! posts (remove* solved posts))
               (loop)]
              [_ (fail "timeout")])))
        (check-true
         (unsat? (verify #:pre (list (even? x))
                         #:post (list (odd? (+ x (sol h)))))))
        (thread-send T (list (not (= h 17))))
        (check result-solution=? (thread-receive) (unsat))
        (check-true (thread-dead? T))
        (custodian-shutdown-all (current-custodian))))))

(define/provide-test-suite
  solver+-tests
  (test0)
  (test1)
  (test2)
  (test3)
  (test4)
  (test5)
  (test6)
  (test7)
  (test8)
  )

(run-tests-quiet solver+-tests)
