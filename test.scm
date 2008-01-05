(use-modules (oop goops)
	     (srfi srfi-39)
	     (ice-9 pretty-print)
	     (oop goops)
	     (ice-9 common-list)
	     (ice-9 rdelim))

(debug-enable 'debug)
(debug-enable 'backtrace)
(debug-set! stack 2000000)
(read-enable 'positions)
(read-set! keywords 'prefix)

(set! pk (lambda args
	   (display ";;;")
	   (for-each (lambda (elt)
		       (display " ")
		       (write elt))
		     args)
	   (newline)
	   (car (last-pair args))))

(load "suo-cross.scm")

(boot-load-book "base.book")
(boot-load-book "utilities.book")
(boot-load-book "assembler.book")
(boot-load-book "compiler.book")
(boot-load-book "books.book")
(image-import-boot-record-types)

(define (write-image mem file)
  (let* ((port (open-output-file file)))
    (uniform-vector-write #u32(#xABCD0002 0 0) port)
    (uniform-vector-write mem port)))

(define (make-bootstrap-image exp file)
  (let ((comp-exp (boot-eval
		   `(compile '(lambda ()
				,exp
				(primop syscall))))))
    (or (constant? comp-exp)
	(error "expected constant"))
    (write-image (dump-object (constant-value comp-exp))
		 file)))

(define (compile-base)
  (image-load-book "base.book")
  (image-load-book "null-compiler.book")
  (image-load-book "books.book")
  (image-load-book "boot.book")
  (image-import-books)
  (make-bootstrap-image (image-expression) "base"))

(define (compile-compiler)
  (image-load-book "base.book")
  (image-load-book "utilities.book")
  (image-load-book "assembler.book")
  (image-load-book "compiler.book")
  (image-load-book "books.book")
  (image-load-book "boot.book")
  (image-import-books)
  (make-bootstrap-image (image-expression) "compiler"))

(define (compile-minimal)
  (boot-eval '(set! cps-verbose #t))
  (make-bootstrap-image
   '(begin
      (define foo 12))
   "minimal"))

(compile-base)
;;(compile-compiler)
;;(compile-minimal)

(boot-eval '(dump-sigs-n-calls))
(check-undefined-variables)
