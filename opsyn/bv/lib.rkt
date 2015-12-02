#lang s-exp rosette

(require "lang.rkt")

; A library of utilites for working with programs and instructions.

(provide (all-defined-out))

; Returns the predicate that recognizes instructions constructed 
; with the given constructor.
; The constructor must be concrete, since we are using (fast) 
; Racket matching instead of (slow) Rosette matching provided 
; by rosette/lib/reflect/match.
(define (instruction->predicate inst)
  (match inst
    [(== bv)      bv?]
    [(== bvadd)   bvadd?]
    [(== bvsub)   bvsub?]
    [(== bvand)   bvand?]
    [(== bvor )   bvor?]
    [(== bvnot)   bvnot?]
    [(== bvshl)   bvshl?]
    [(== bvashr)  bvashr?]
    [(== bvlshr)  bvlshr?]
    [(== bvneg)   bvneg?]
    [(== bvredor) bvredor?]
    [(== bvmax)   bvmax?]
    [(== bvmin)   bvmin?]
    [(== bvabs)   bvabs?]
    [(== bvxor)   bvxor?]
    [(== bvsle)   bvsle?]
    [(== bvslt)   bvslt?]
    [(== bveq)    bveq?]
    [(== bvule)   bvule?]
    [(== bvult)   bvult?]
    [(== ite)     ite?]
    [(== bvmul)   bvmul?]
    [(== bvsdiv)  bvsdiv?]
    [(== bvsrem)  bvsrem?]
    [(== bvudiv)  bvudiv?]
    [(== bvurem)  bvurem?]
    [(== bvsqrt)  bvsqrt?]
    [(== shr1)    shr1?]
    [(== shr4)    shr4?]
    [(== shr16)   shr16?]
    [(== shl1)    shl1?]
    [(== if0)     if0?]))