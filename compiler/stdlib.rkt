; WINGS Operating System
; Copyright (C) 2016 Alyssa Rosenzweig
; 
; This file is part of WINGS.
; 
; WINGS is free software: you can redistribute it and/or modify
; it under the terms of the GNU Affero General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
; 
; WINGS is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
; 
; You should have received a copy of the GNU General Public License
; along with WINGS.  If not, see <http://www.gnu.org/licenses/>.

; depends on cons, car, cdr, null?, if, empty?
; supports length, 
; first..fourth, rest
; caar...cddr,
; reverse
; append

#lang racket

(define (_length l)
  (if (empty? l)
    0
    (length-compute l 0)))

(define (length-compute l base)
  (if (null? (cdr l))
    (+ base 1)
    (length-compute (cdr l) (+ base 1))))

(define (_first l) (car l))
(define (_rest l) (cdr l))

(define (_second l) (car (cdr l)))
(define (_third l) (car (cdr (cdr l))))
(define (_fourth l) (car (cdr (cdr (cdr l)))))

(define (_caar l) (car (car l)))
(define (_cadr l) (car (cdr l)))
(define (_cdar l) (cdr (car l)))
(define (_cddr l) (cdr (cdr l)))

(define (_reverse l)
  (reverse-compute l '()))

(define (reverse-compute remaining emitted)
  (if (empty? remaining)
    emitted
    (reverse-compute (rest remaining) (cons (first remaining) emitted))))

(define (_append head tail)
  (append-compute (reverse head) tail))

(define (append-compute head tail)
  (if (empty? head)
    tail
    (append-compute (rest head) (cons (first head) tail))))