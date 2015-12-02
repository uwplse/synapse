#lang racket

(provide logging? log-id log-start-time log-search log-cegis)

(define logging? (make-parameter #f))
(define log-id (make-parameter #f))
(define log-start-time (make-parameter (current-inexact-milliseconds)))

(define (format-time t)
   (~r (/ t 1000) #:precision 3))

(define (time-string search-start-time [my-start-time #f])
  (define δt (format-time (- (current-inexact-milliseconds) search-start-time)))
  (cond [my-start-time 
         (define my-time (format-time (- (current-inexact-milliseconds) my-start-time)))
         (format "t=~as; ~as" δt my-time)]
        [else
         (format "t=~as" δt)]))

(define-syntax log-driver
  (syntax-rules ()
    [(_ [src] [t] pred msg rest ...)
     (when (pred (logging?))
       (parameterize ([error-print-width 100000])
         (printf "[~a] [~a]~a ~a\n"
                 src
                 (time-string (log-start-time) t)
                 (if (false? (log-id)) "" (format " [p~a]" (log-id)))
                 (format msg rest ...)))
       (flush-output))]
    [(_ [src] pred msg rest ...)
     (log-driver [src] [#f] pred msg rest ...)]))

(define-syntax log-search
  (syntax-rules ()
    [(_ [t] msg rest ...)
     (log-driver ['search] [t] (compose not false?) msg rest ...)]
    [(_ msg rest ...)
     (log-search [#f] msg rest ...)]))

(define-syntax log-cegis
  (syntax-rules ()
    [(_ [trial] [t] msg rest ...)
     (log-driver ['icegis] [t] (lambda (b) (and (number? b) (> b 1))) (format "[r~a] ~a" trial (format msg rest ...)))]
    [(_ [trial] msg rest ...)
     (log-cegis [trial] [#f] msg rest ...)]))