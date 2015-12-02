#lang s-exp rosette

(require "../../opsyn/bv/lang.rkt")
(provide (all-defined-out))

; Turn off the rightmost 1-bit in a bit-vector.
(define hd01 ;(x)
  (program
   1
   (list
    #| 1|# (bv 1)
    #| 2|# (bvsub 0 1)
    #| 3|# (bvand 0 2))))

; Test if unsigned int is of form 2^n - 1
(define hd02 ;(x)
  (program
   1
   (list
    #| 1|# (bv 1)
    #| 2|# (bvadd 0 1)
    #| 3|# (bvand 0 2))))

; Isolate the right most one bit
(define hd03 ;(x)
  (program
   1
   (list
    #| 1|# (bvneg 0)
    #| 2|# (bvand 0 1))))

; Form a bit mask that identifies the rightmost one bit and trailing zeros
(define hd04 ;(x)
  (program
   1
   (list
    #| 1|# (bv 1)
    #| 2|# (bvsub 0 1)
    #| 3|# (bvxor 0 2))))

; Right propagate the rightmost one bit
(define hd05 ;(x)
  (program
   1
   (list
    #| 1|# (bv 1)
    #| 2|# (bvsub 0 1)
    #| 3|# (bvor 0 2))))

; Turn on the right most 0 bit
(define hd06 ;(x)
  (program
   1
   (list
    #| 1|# (bv 1)
    #| 2|# (bvadd 0 1)
    #| 3|# (bvor 0 2))))

; Isolate the rightmost 0 bit
(define hd07 ;(x)
  (program
   1
   (list
    #| 1|# (bvnot 0)
    #| 2|# (bv 1)
    #| 3|# (bvadd 0 2)
    #| 4|# (bvand 1 3))))

; Form a mask that identifies the trailing zeros
(define hd08 ;(x)
  (program
   1
   (list
    #| 1|# (bv 1)
    #| 2|# (bvsub 0 1)
    #| 3|# (bvnot 0)
    #| 4|# (bvand 2 3))))

; Absolute value function
(define hd09 ;(x)
  (program
   1
   (list
    #| 1|# (bv 31)
    #| 2|# (bvashr 0 1)
    #| 3|# (bvxor 0 2)
    #| 4|# (bvsub 3 2))))

; Test if (nlz x) == (nlz y) where nlz is the number of leading zeros
(define hd10 ;(x y)
  (program
   2
   (list
    #| 2|# (bvand 0 1)
    #| 3|# (bvxor 0 1)
    #| 4|# (bvule 3 2))))  ; BUG in SyGuS benchmark: o2 and o1 are reversed

; Test if (nlz x) < (nlz y) where nlz is the number of leading zeros
(define hd11 ;(x y)
  (program
   2
   (list
    #| 2|# (bvnot 1)
    #| 3|# (bvand 0 2)
    #| 4|# (bvult 1 3))))

; Test if (nlz x) <= (nlz y) where nlz is the number of leading zeros
(define hd12 ;(x y)  ; BUG in the paper & SyGuS benchmark: x and y reversed
  (program
   2
   (list
    #| 2|# (bvnot 0)
    #| 3|# (bvand 1 2)
    #| 4|# (bvule 3 0))))

; sign function
(define hd13 ;(x)
  (program
   1
   (list
    #| 1|# (bv 31)
    #| 2|# (bvashr 0 1)
    #| 3|# (bvneg 0)
    #| 4|# (bvlshr 3 1)
    #| 5|# (bvor 2 4))))

; floor of average of two integers
(define hd14 ;(x y)
  (program
   2
   (list
    #| 2|# (bvand 0 1)
    #| 3|# (bvxor 0 1)
    #| 4|# (bv 1)
    #| 5|# (bvlshr 3 4)
    #| 6|# (bvadd 2 5))))

; ceil of average of two integers
(define hd15 ;(x y)
  (program
   2
   (list
    #| 2|# (bvor 0 1)
    #| 3|# (bvxor 0 1)
    #| 4|# (bv 1)
    #| 5|# (bvlshr 3 4)
    #| 6|# (bvsub 2 5))))

; max of two unsigned integers (not in HD suite)
(define hd16 ;(x y)
  (program
   2
   (list
    #| 2|# (bvxor 0 1)
    #| 3|# (bvule 1 0)
    #| 4|# (bvneg 3)
    #| 5|# (bvand 2 4)
    #| 6|# (bvxor 5 1))))

; turn off the rightmost string of contiguous ones
(define hd17 ;(x)
  (program
   1
   (list
    #| 1|# (bv 1)
    #| 2|# (bvsub 0 1)
    #| 3|# (bvor 0 2)
    #| 4|# (bvadd 3 1)
    #| 5|# (bvand 4 0))))

; determine if power of two
(define hd18 ;(x)
  (program
   1
   (list
    #| 1|# (bv 1)
    #| 2|# (bvsub 0 1)
    #| 3|# (bvand 2 0)
    #| 4|# (bvredor 0)
    #| 5|# (bvredor 3)
    #| 6|# (bvnot 5)
    #| 7|# (bvand 6 4))))

; exchange fields A and B in register x
(define hd19 ;(x m k)
  (program
   3
   (list
    #| 3|# (bvlshr 0 2)
    #| 4|# (bvxor 0 3)
    #| 5|# (bvand 4 1)
    #| 6|# (bvshl 5 2)
    #| 7|# (bvxor 6 5)
    #| 8|# (bvxor 7 0))))

; next higher unsigned number with same number of 1 bits
(define hd20 ;(x)
  (program
   1
   (list
    #| 1|# (bvneg 0)
    #| 2|# (bvand 0 1)
    #| 3|# (bvadd 0 2)
    #| 4|# (bvxor 0 2)
    #| 5|# (bv 2)
    #| 6|# (bvlshr 4 5)
    #| 7|# (bvudiv 6 2)
    #| 8|# (bvor 7 3))))

(define all-hd-programs
  (list hd01 hd02 hd03 hd04 hd05 hd06 hd07 hd08 hd09 hd10
        hd11 hd12 hd13 hd14 hd15 hd16 hd17 hd18 hd19 hd20))