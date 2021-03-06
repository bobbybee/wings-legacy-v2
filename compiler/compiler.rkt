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

#lang racket

(require racket)
(include "stdlib.rkt")

; in the future, this is a lower-level call to resolve a URL
; but for now, this is just a thin wrapper around the Racket API

(define (recursive-resolve str index data)
  (if (> (string-length str) index)
    (let ([datum (read-compute str index)])
      (recursive-resolve str (last datum) (cons (first datum) data)))
    (reverse data)))

(define (resolve url)
  (let* ([handle (open-input-file url)]
         [str (string-trim (port->string handle))]
         [content (recursive-resolve str 0 '())])
    (close-input-port handle)
    content))

; compile s-expressions to IR
; emits (list ir identifier (hash base locals globals closures)

(define (expression-to-ir code ctx)
  (cond
    [(list? code)
     (case (first code) [(lambda) (lambda-to-ir code
                                                (hash-set (hash-set ctx 'base 0)
                                                          'locals '())
                                                ctx)]
                        [(define) (define-to-ir code ctx)]
                        [(quote) (quote-to-ir (second code) ctx)]
                        [(let) (let-to-ir code '() ctx)] ; todo: differentiate
                        [(let*) (let-to-ir code '() ctx)]
                        [(match-let) (match-let-to-ir code '() ctx)]
                        [(match-let*) (match-let-to-ir code '() ctx)]
                        [(make-symbol) (list '()
                                             (list "symbol" (second code))
                                             ctx)]
                        [(if) (if-to-ir code ctx)]
                        [(cond) (cond-to-ir code ctx)]
                        [else (call-to-ir code ctx)])]
    [(number? code)
     (list '() (list "imm" code) ctx)]
    [(string? code)
     (list '() (list "immstr" code) ctx)]
    [(member code (hash-ref ctx 'locals))
     (list '() (list "closure" code) ctx)]
    [(hash-has-key? (hash-ref ctx 'globals) code)
     (list '() (list "global" code) ctx)]
    [(boolean? code)
     (list '() (list "immbool" code) ctx)]
    [(char? code)
     (list '() (list "immchar" code) ctx)]
    [else ; next pass's problem I guess
     (list '() (list "global" code) ctx)]))

(define (define-to-ir code ctx)
  (if (list? (second code))
    (define-to-ir 
      (list 'define
            (first (second code))
            (append (list 'lambda (rest (second code))) (cddr code)))
      ctx)
    (match-let ([(list ir identifier nctx) (expression-to-ir (third code) ctx)])
      (list '() #f (hash-set nctx 'globals (hash-set (hash-ref nctx 'globals)
                                                     (second code)
                                                     identifier))))))

(define (lambda-to-ir code ctx octx)
  (match-let ([(list ir identifier nctx)
               (expression-to-ir (third code)
                                 (hash-set ctx 'locals (append (second code)
                                                               (hash-ref ctx 'locals))))])
             (list '()
                   (list "lambda" (length (hash-ref ctx 'lambdas))) 
                   (hash-set octx 'lambdas
                             (cons (cons (second code) 
                                         (reverse (cons (list "="
                                                              (list "return")
                                                              (list "stack" (- (hash-ref nctx 'base) 1)))
                                                        ir)))
                                   (hash-ref nctx 'lambdas))))))

; May be unstable -- rewrite later
(define (quote-to-ir code ctx)
  (cond [(list? code) (expression-to-ir (cons 'list code) ctx)]
        [(symbol? code) (expression-to-ir (list 'make-symbol code) ctx)]))

(define (let-to-ir code ir ctx)
  (if (= (length (second code)) 0)
    (let ([value (expression-to-ir (third code) ctx)])
      (list (append (first value) ir) (second value) (third value)))
    (let ([value (expression-to-ir (second (first (second code))) ctx)])
      (let-to-ir (list "let" (rest (second code)) (third code))
                 (cons (list "=" (first (first (second code))) (second value))
                       (append (first value) ir))
                 (hash-set (third value)
                           'locals
                           (cons (first (first (second code)))
                                 (hash-ref (third value) 'locals)))))))

(define (match-let-to-ir code ir ctx)
  (if (= (length (second code)) 0)
    (let ([body (expression-to-ir (third code) ctx)])
      (list (append (first body) ir) (second body) (third body)))
    (let* ([expression (expression-to-ir (second (first (second code))) ctx)]
           [result (match-ir (first (first (second code)))
                             (second expression)
                             '()
                             #t
                             (third expression))])
      (match-let-to-ir (list "match-let" (rest (second code)) (third code))
                       (append (first result) ir)
                       (second result)))))

(define (match-ir pattern needle ir load? ctx)
  (cond [(symbol? pattern) (match-symbol-ir pattern needle ir load? ctx)]
        [(list? pattern) (match-list-ir pattern needle ir load? ctx)]
        [else (display "Ahhh!!! Unknown match target\n")]))

(define (match-symbol-ir pattern needle ir load? ctx)
  (let ([sanity (expression-to-ir (list 'symbol? needle) ctx)])
    (list (cons (list "=" (list "closure" pattern) needle)
                (append (first sanity) ir))
          (hash-set (third sanity)
                    'locals
                    (cons pattern (hash-ref (third sanity) 'locals))))))

(define (match-list-ir pattern needle ir load? ctx)
  (let* ([sanity (expression-to-ir
                   (list 'and 
                         (list 'list? needle)
                         (list '= 
                               (list 'length needle) 
                               (- (length pattern) 1)))
                   ctx)])
    (match-list-body-ir (rest pattern)
                        needle
                        (append (first sanity) ir)
                        load?
                        (third sanity))))

(define (match-list-body-ir pattern needle ir load? ctx)
  (if (= (length pattern) 0)
    (list ir ctx)
    (let* ([current-match
            (match-ir (first pattern)
                      (list "stack" (hash-ref ctx 'base))
                      (cons (list "="
                                    (list "stack" (hash-ref ctx 'base))
                                    (list "call" "first" needle)) ir)
                      load?
                      (hash-set ctx 'base (+ (hash-ref ctx 'base) 1)))]
           [nctx (second current-match)])
      (match-list-body-ir (rest pattern)
                          (list "stack" (hash-ref nctx 'base))
                          (cons (list "="
                                      (list "stack" (hash-ref nctx 'base))
                                      (list "call" "rest" needle))
                                (first current-match))
                          load?
                          (hash-set nctx 'base (+ (hash-ref nctx 'base) 1))))))

(define (call-to-ir code ctx)
  (let ([function (expression-to-ir (first code) ctx)])
    (match-let ([(list ir emission identifiers nctx)
                 (arguments-to-ir (rest code) '() '() (third function))])
      (list (cons (list "=" 
                        (list "stack" (hash-ref nctx 'base))
                        (append (list "call" (second function))
                                (reverse identifiers)))
                  (append emission (first function)))
            (list "stack" (hash-ref nctx 'base))
            (hash-set nctx 'base (+ (hash-ref nctx 'base) 1))))))
  
(define (arguments-to-ir code emission identifiers ctx)
  (if (empty? code)
    (list '() emission identifiers ctx)
    (match-let ([(list ir id nctx) (expression-to-ir (first code) ctx)])
      (arguments-to-ir
        (rest code) 
        (append ir emission)
        (cons id identifiers)
        nctx))))

; if-statements have a special form to allow short-circuiting

(define (if-to-ir code ctx)
  (let* ([condition (expression-to-ir (second code) ctx)]
         [pathA (expression-to-ir (third code) (third condition))]
         [pathB (expression-to-ir (fourth code) (third pathA))]
         [nbase (hash-ref (third pathB) 'base)])
    (list (cons (list "="
                      (list "stack" nbase)
                      (list "if" (second condition)
                                 (second pathA) (first pathA)
                                 (second pathB) (first pathB)))
                (first condition))
          nbase
          (hash-set (third pathB) 'base (+ nbase 1)))))

(define (cond-to-ir code ctx)
  (if (= (length code) 2)
    (if (eq? (first (second code)) 'else)
      (expression-to-ir (second (second code)) ctx)
      (expression-to-ir (list 'if
                              (first (second code))
                              (second (second code))
                              (list 'error "Unresolved cond"))
                        ctx))
    (expression-to-ir (list 'if
                            (first (second code))
                            (second (second code))
                            (cons 'cond (rest (rest code)))) ctx)))
  
(define (program-to-ir sexpr ir globals lambdas)
    (if (empty? sexpr)
      (list (reverse ir) globals lambdas)
      (let ([expression (expression-to-ir (first sexpr) (hash 'locals '()
                                                              'globals globals
                                                              'base 0
                                                              'lambdas lambdas))])
        (program-to-ir (rest sexpr)
                       (cons (reverse (first expression)) ir) 
                       (hash-ref (third expression) 'globals)
                       (hash-ref (third expression) 'lambdas)))))

(pretty-print
  (program-to-ir (resolve (vector-ref (current-command-line-arguments) 0))
                 '()
                 (hash)
                 '()))
