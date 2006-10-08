(display "Hello, Suo!")
(newline)

(define big+ #x806e0000)
;;(define big- -2154692608)

(define (<< a n)
  (bignum-shift-limbs a n))

(define (fac n)
  (if (< n 3) n (* n (fac (1- n)))))

(define count 0)

(define (test val1 val2)
  (if (= val1 val2)
      (begin 
	(set! count (1+ count))
	(pk 'PASS count)
	(values))
      (error "FAIL" val1 val2)))

(define (eval-special form)
  (let ((key (car form)))
    (case key
      ((:quote)
       (cadr form))
      ((:set :define)
       (let* ((sym (cadr form))
	      (val (mock-eval (caddr form)))
	      (var (lookup-toplevel-variable sym)))
	 (variable-set! var val)))
      (else
       (error "unsupported special: " key)))))

(define (mock-eval form)
  (let ((form (compile form)))
    (cond
     ((symbol? form)
      (variable-ref (lookup-toplevel-variable form)))
     ((pair? form)
      (if (keyword? (car form))
	  (eval-special form)
	  (let ((vals (map mock-eval form)))
	    (apply (car vals) (cdr vals)))))
     (else
      form))))

(define (repl)
  (call/cc
   (lambda (k)
     (with-error-handler
      (lambda args
	(apply display-error args)
	(k #f))
      (lambda ()
	(call/v (lambda () (mock-eval (read)))
		(lambda vals
		  (for-each (lambda (v)
			      (write v)
			      (newline))
			    vals)))))))
  (repl))

(define (suspend)
  (let ((hashq-vectors (get-hashq-vectors)))
    (call/cc (lambda (k)
	       (primop syscall 10 (lambda () (k #t)))
	       (error "can't suspend")))
    (set-hashq-vectors hashq-vectors)
    #t))

(display (length toplevel))
(display " toplevel bindings\n")

(repl)