;;; Code generation and assembling

(declare-variables cps-verbose)

(define (cps-asm-insn-1 ctxt op xyz)
  (cps-asm-u32-2 ctxt
		 (+ (* op 256) (quotient xyz 32768))
		 (remainder xyz 32768)))

(define (cps-asm-insn-2 ctxt op x yz)
  (cps-asm-u32-2 ctxt (+ (* op 256) x) yz))

(define (cps-asm-insn-2-with-laboff ctxt op x lab)
  (cps-asm-u32-with-laboff ctxt (+ (* op 256) x) lab))

(define (cps-asm-insn-3 ctxt op x y z)
  (cps-asm-u32-2 ctxt (+ (* op 256) x) (+ (* y 256) z)))

(define (u8-const? obj off)
  (and (cps-quote? obj)
       (let ((val (cps-quote-value obj)))
	 (and (fixnum? val)
	      (<= 0 (+ val off))
	      (< (+ val off) 256)))))

(define (s16-const? obj)
  (and (cps-quote? obj)
       (let ((val (cps-quote-value obj)))
	 (and (fixnum? obj)
	      (<= -32768 val)
	      (< val 32768)))))

(define RR 0)
(define RL 1)
(define LR 2)
(define LL 3)

(define HALT           0)
(define MISC           4)
(define MOVE           8)
(define REF           12)
(define REFI          16)
(define SET           20)
(define SETL          24)
(define SETI          28)
(define CMP           32)
(define TRAP          36)
(define REFU8         40)
(define SETU8         44)
(define REFU16        48)
(define SETU16        52)
(define ADD           56)
(define SUB           60)
(define MUL           64)
(define DIV           68)
(define REM           72)
(define ADD16         76)
(define SUB16         80)
(define MUL16         84)
(define DIV16         88)
(define ADD16I        92)

(define MOVEI        128)
(define ALLOCI       129)
(define INITI        130)
(define FILLI        131)
(define CHECK_ALLOCI 132)
(define INIT_VECI    133)

(define BRANCH       255)

(define MISCOP_GO            0)
(define MISCOP_ALLOC         1)
(define MISCOP_INIT          2)
(define MISCOP_INIT_REC      3)
(define MISCOP_INIT_VEC      4)
(define MISCOP_FILL          5)
(define MISCOP_COPY          6)
(define MISCOP_LOAD_DESC     7)
(define MISCOP_LOAD_LENGTH   8)
(define MISCOP_TEST_REC      9)
(define MISCOP_TEST_VEC     10)
(define MISCOP_TEST_DESC    11)
(define MISCOP_TEST_PAIR    12)
(define MISCOP_LOAD_LENGTH_HALF 13)
(define MISCOP_ALLOC_BYTES  14)
(define MISCOP_TEST_CHAR    15)
(define MISCOP_MAKE_CHAR    16)
(define MISCOP_CHAR_VALUE   17)
(define MISCOP_TEST_FIXNUM  18)
(define MISCOP_SET_COUNT    19)
(define MISCOP_SET_COUNT_HI 20)
(define MISCOP_GET_COUNT    21)
(define MISCOP_GET_COUNT_HI 22)
(define MISCOP_LOAD_INSN_LENGTH 23)
(define MISCOP_LOAD_LIT_LENGTH 24)
(define MISCOP_ALLOC_CODE   25)
(define MISCOP_INIT_CODE    26)

(define CMPOP_EQ             0)
(define CMPOP_FIXNUMS        1)

(define TRAPOP_SYSCALL           0)
(define TRAPOP_CHECK_CALLSIG     1)
(define TRAPOP_CHECK_ALLOC       2)
(define TRAPOP_CHECK_ALLOC_BYTES 3)
(define TRAPOP_CHECK_ALLOC_CODE  4)

(define IF_FALSE             0)
(define IF_GTE               1)

(define IMM_UNSPEC 26)

(define TAG_VECTOR   3)
(define TAG_BYTEVEC 11)
(define TAG_CODE    15)

(define (cps-asm-reglit-insn ctxt op x y z)

  (define (val p)
    (cond ((cps-reg? p)
	   (cps-reg-idx p))
	  ((cps-quote? p)
	   (cps-asm-litidx ctxt (cps-quote-value p)))
	  (else
	   p)))
  
  (cps-asm-insn-3 ctxt (+ op
			  (if (cps-quote? y) 2 0)
			  (if (cps-quote? z) 1 0))
		  (if (cps-reg? x) (cps-reg-idx x) x) (val y) (val z)))

(define (cps-asm-branch ctxt op lab)
  (cps-asm-insn-2-with-laboff ctxt BRANCH op lab))

(define (cps-asm-shuffle ctxt from to)

  (define (move src dst)
    (if cps-verbose
	(pk (cps-render src) '-> (cps-render dst)))
    (let ((src (if (eq? src 'tmp) 255 src))
	  (dst (if (eq? dst 'tmp) 255 dst)))
      (if (s16-const? src)
	  (cps-asm-insn-2 ctxt MOVEI 
			  (if (cps-reg? dst)
			      (cps-reg-idx dst)
			      dst)
			  (cps-quote-value src))
	  (cps-asm-reglit-insn ctxt MOVE dst src 0))))
  
  (cps-asm-shuffle-with-move ctxt from to move))

(define (cps-asm-go ctxt to)
  (cps-asm-reglit-insn ctxt MISC 0 to MISCOP_GO))

(define (cps-asm-prologue ctxt sig alloc-size)
  (cps-asm-reglit-insn ctxt TRAP sig 0 TRAPOP_CHECK_CALLSIG)
  (cps-asm-alloc-check ctxt alloc-size #t))

(define (cps-asm-alloc-check ctxt size always?)
  (if (or (> size 0) always?)
      (cps-asm-insn-1 ctxt CHECK_ALLOCI size)))

(define-primop (syscall (res) args)
  (asm
   (cps-asm-reglit-insn ctxt TRAP
			(cps-reg-idx res) (length args) TRAPOP_SYSCALL)
   (for-each (lambda (a)
	       (cond ((cps-reg? a)
		      (cps-asm-u32-2 ctxt 0 (cps-reg-idx a)))
		     (else
		      (cps-asm-u32-2 ctxt
				     #x8000
				     (cps-asm-litidx ctxt
						     (cps-quote-value a))))))
	     args)))

(define (cps-asm-panic ctxt)
  (cps-asm-insn-1 ctxt HALT 0))

(define-primop (record (res) (desc . values))
  (alloc-size
   (1+ (length values)))
  (asm
   (cps-asm-insn-2 ctxt ALLOCI (cps-reg-idx res) (1+ (length values)))
   (cps-asm-reglit-insn ctxt MISC 0 desc MISCOP_INIT_REC)
   (for-each (lambda (v)
	       (cps-asm-reglit-insn ctxt MISC 0 v MISCOP_INIT))
	     values)))

(define-primop (make-record (res) (desc n-fields init))
  (alloc-size
   #t)
  (asm
   (cps-asm-reglit-insn ctxt TRAP 0 n-fields TRAPOP_CHECK_ALLOC)
   (cps-asm-reglit-insn ctxt MISC res n-fields MISCOP_ALLOC)
   (cps-asm-reglit-insn ctxt MISC 0 desc MISCOP_INIT_REC)
   (cps-asm-reglit-insn ctxt MISC 0 init MISCOP_FILL)))

(define-primif (if-record? (obj desc) (else-label))
  (asm
   (cps-asm-reglit-insn ctxt MISC 0 obj MISCOP_TEST_REC)
   (if (not (and (cps-quote? desc)
		 (eq? (cps-quote-value desc) #t)))
       (cps-asm-reglit-insn ctxt MISC 0 desc MISCOP_TEST_DESC))
   (cps-asm-branch ctxt IF_FALSE else-label)))

(define-primop (record-desc (res) (rec))
  (asm
   (cps-asm-reglit-insn ctxt MISC res rec MISCOP_LOAD_DESC)))

(define-primop (record-ref (res) (rec idx))
  (asm
   (if (u8-const? idx 1)
       (cps-asm-reglit-insn ctxt REFI res rec (1+ (cps-quote-value idx)))
       (cps-asm-reglit-insn ctxt REF res rec idx))))

(define-primop (record-set (res) (rec idx val))
  (asm
   (if (cps-reg? rec)
       (if (u8-const? idx 1)
	   (cps-asm-reglit-insn ctxt SETI rec val (1+ (cps-quote-value idx)))
	   (cps-asm-reglit-insn ctxt SET rec val idx))
       (cps-asm-reglit-insn ctxt SETL
			    (cps-asm-litidx ctxt (cps-quote-value rec))
			    val idx))
   (cps-asm-insn-2 ctxt MOVEI (cps-reg-idx res) IMM_UNSPEC)))

(define-primif (if-vector? (a) (else-label))
  (asm
   (cps-asm-reglit-insn ctxt MISC TAG_VECTOR a MISCOP_TEST_VEC)
   (cps-asm-branch ctxt IF_FALSE else-label)))

(define-primop (vector (res) values)
  (alloc-size
   (1+ (length values)))
  (asm
   (cps-asm-insn-2 ctxt ALLOCI (cps-reg-idx res) (1+ (length values)))
   (cps-asm-insn-1 ctxt INIT_VECI (+ (* 16 (length values)) TAG_VECTOR))
   (for-each (lambda (v)
	       (cps-asm-reglit-insn ctxt MISC 0 v MISCOP_INIT))
	     values)))

(define-primop (make-vector (res) (n init))
  (alloc-size
   #t)
  (asm
   (cps-asm-reglit-insn ctxt TRAP 0 n TRAPOP_CHECK_ALLOC)
   (cps-asm-reglit-insn ctxt MISC res n MISCOP_ALLOC)
   (cps-asm-reglit-insn ctxt MISC TAG_VECTOR n MISCOP_INIT_VEC)
   (cps-asm-reglit-insn ctxt MISC 0 init MISCOP_FILL)))

(define-primop (vector-length (res) (a))
  (asm
   (cps-asm-reglit-insn ctxt MISC res a MISCOP_LOAD_LENGTH)))

(define-primop (vector-ref (res) (vec idx))
  (asm
   (if (u8-const? idx 1)
       (cps-asm-reglit-insn ctxt REFI res vec (1+ (cps-quote-value idx)))
       (cps-asm-reglit-insn ctxt REF res vec idx))))

(define-primop (vector-set (res) (vec idx val))
  (asm
   (if (cps-reg? vec)
       (if (u8-const? idx 1)
	   (cps-asm-reglit-insn ctxt SETI vec val (1+ (cps-quote-value idx)))
	   (cps-asm-reglit-insn ctxt SET vec val idx))
       (cps-asm-reglit-insn ctxt SETL
			    (cps-asm-litidx ctxt (cps-quote-value vec))
			    val idx))
   (cps-asm-insn-2 ctxt MOVEI (cps-reg-idx res) IMM_UNSPEC)))

(define-primif (if-eq? (v1 v2) (else-label))
  (asm
   (cps-asm-reglit-insn ctxt CMP CMPOP_EQ v1 v2)
   (cps-asm-branch ctxt IF_FALSE else-label)))

(define-primop (cons (res) (a b))
  (alloc-size
   2)
  (asm
   (cps-asm-insn-2 ctxt ALLOCI (cps-reg-idx res) 2)
   (cps-asm-reglit-insn ctxt MISC 0 a MISCOP_INIT)
   (cps-asm-reglit-insn ctxt MISC 0 b MISCOP_INIT)))

(define-primif (if-pair? (a) (else-label))
  (asm
   (cps-asm-reglit-insn ctxt MISC TAG_VECTOR a MISCOP_TEST_PAIR)
   (cps-asm-branch ctxt IF_FALSE else-label)))

(define-primop (car (res) (a))
  (asm
   (cps-asm-reglit-insn ctxt REFI res a 0)))

(define-primop (cdr (res) (a))
  (asm
   (cps-asm-reglit-insn ctxt REFI res a 1)))

(define-primop (set-car (res) (a b))
  (asm
   (cps-asm-reglit-insn ctxt SETI a b 0)))

(define-primop (set-cdr (res) (a b))
  (asm
   (cps-asm-reglit-insn ctxt SETI a b 1)))

(define-primif (if-fixnum? (v) (else-label))
  (asm
   (cps-asm-reglit-insn ctxt MISC TAG_VECTOR v MISCOP_TEST_FIXNUM)
   (cps-asm-branch ctxt IF_FALSE else-label)))

(define-primitive (add-fixnum (res) (arg1 arg2) (overflow))
  (asm
   (cps-asm-reglit-insn ctxt ADD res arg1 arg2)
   (cps-asm-branch ctxt IF_FALSE overflow)))

(define-primitive (split-fixnum (hi lo) (a) ())
  (asm
   (cps-asm-reglit-insn ctxt MISC 0 (cps-quote 0) MISCOP_SET_COUNT)
   (cps-asm-reglit-insn ctxt ADD16I lo a 0)
   (cps-asm-reglit-insn ctxt MISC hi 0 MISCOP_GET_COUNT_HI)))
   
(define-primitive (add-fixnum2 (hi lo) (a b k) ())
  (asm
   (cps-asm-reglit-insn ctxt MISC 0 k MISCOP_SET_COUNT)
   (cps-asm-reglit-insn ctxt ADD16 lo a b)
   (cps-asm-reglit-insn ctxt MISC hi 0 MISCOP_GET_COUNT_HI)))

(define-primitive (sub-fixnum (res) (arg1 arg2) (overflow))
  (asm
   (cps-asm-reglit-insn ctxt SUB res arg1 arg2)
   (cps-asm-branch ctxt IF_FALSE overflow)))

(define-primitive (sub-fixnum2 (hi lo) (a b k) ())
  (asm
   (cps-asm-reglit-insn ctxt MISC 0 k MISCOP_SET_COUNT)
   (cps-asm-reglit-insn ctxt SUB16 lo a b)
   (cps-asm-reglit-insn ctxt MISC hi 0 MISCOP_GET_COUNT_HI)))

(define-primitive (mul-fixnum (res) (arg1 arg2) (overflow))
  (asm
   (cps-asm-reglit-insn ctxt MUL res arg1 arg2)
   (cps-asm-branch ctxt IF_FALSE overflow)))

(define-primitive (mul-fixnum2 (hi lo) (a b c k) ())
  (asm
   (cps-asm-reglit-insn ctxt MISC 0 k MISCOP_SET_COUNT)
   (cps-asm-reglit-insn ctxt ADD16I lo c 0)
   (cps-asm-reglit-insn ctxt MUL16  lo a b)
   (cps-asm-reglit-insn ctxt MISC hi 0 MISCOP_GET_COUNT_HI)))

(define-primitive (quotrem-fixnum2 (q r) (a b c) ())
  (asm
   (cps-asm-reglit-insn ctxt MISC 0 b MISCOP_SET_COUNT)
   (cps-asm-reglit-insn ctxt MISC 0 a MISCOP_SET_COUNT_HI)
   (cps-asm-reglit-insn ctxt DIV16 q c 0)))

(define-primop (quotient-fixnum (res) (arg1 arg2))
  (asm
   (cps-asm-reglit-insn ctxt DIV res arg1 arg2)))

(define-primop (remainder-fixnum (res) (arg1 arg2))
  (asm
   (cps-asm-reglit-insn ctxt REM res arg1 arg2)))

(define-primif (if-< (v1 v2) (else-label))
  (asm
   (cps-asm-reglit-insn ctxt CMP CMPOP_FIXNUMS v1 v2)
   (cps-asm-branch ctxt IF_GTE else-label)))

(define-primop (identity (res) (a))
  (asm
   (cps-asm-reglit-insn ctxt MOVE res a 0)))

(define-primif (if-char? (a) (else-label))
  (asm
   (cps-asm-reglit-insn ctxt MISC 0 a MISCOP_TEST_CHAR)
   (cps-asm-branch ctxt IF_FALSE else-label)))

(define-primop (integer->char (res) (a))
  (asm
   (cps-asm-reglit-insn ctxt MISC res a MISCOP_MAKE_CHAR)))

(define-primop (char->integer (res) (a))
  (asm
   (cps-asm-reglit-insn ctxt MISC res a MISCOP_CHAR_VALUE)))

(define-primif (if-bytevec? (a) (else-label))
  (asm
   (cps-asm-reglit-insn ctxt MISC TAG_BYTEVEC a MISCOP_TEST_VEC)
   (cps-asm-branch ctxt IF_FALSE else-label)))

(define-primop (make-bytevec (res) (n))
  (alloc-size
   #t)
  (asm
   (cps-asm-reglit-insn ctxt TRAP res n TRAPOP_CHECK_ALLOC_BYTES)
   (cps-asm-reglit-insn ctxt MISC res n MISCOP_ALLOC_BYTES)
   (cps-asm-reglit-insn ctxt MISC TAG_BYTEVEC n MISCOP_INIT_VEC)))

(define-primop (bytevec-length-8 (res) (a))
  (asm
   (cps-asm-reglit-insn ctxt MISC res a MISCOP_LOAD_LENGTH)))

(define-primop (bytevec-ref-u8 (res) (vec idx))
  (asm
   (cps-asm-reglit-insn ctxt REFU8 res vec idx)))

(define-primop (bytevec-set-u8 (res) (vec idx val))
  (asm
   (cps-asm-reglit-insn ctxt SETU8 vec val idx)
   (cps-asm-insn-2 ctxt MOVEI (cps-reg-idx res) IMM_UNSPEC)))

(define-primop (bytevec-length-16 (res) (a))
  (asm
   (cps-asm-reglit-insn ctxt MISC res a MISCOP_LOAD_LENGTH_HALF)))

(define-primop (bytevec-ref-u16 (res) (vec idx))
  (asm
   (cps-asm-reglit-insn ctxt REFU16 res vec idx)))

(define-primop (bytevec-set-u16 (res) (vec idx val))
  (asm
   (cps-asm-reglit-insn ctxt SETU16 vec val idx)
   (cps-asm-insn-2 ctxt MOVEI (cps-reg-idx res) IMM_UNSPEC)))

(define-primif (if-code? (a) (else-label))
  (asm
   (cps-asm-reglit-insn ctxt MISC TAG_CODE a MISCOP_TEST_VEC)
   (cps-asm-branch ctxt IF_FALSE else-label)))

(define-primop (code-insn-length (res) (c))
  (asm
   (cps-asm-reglit-insn ctxt MISC res c MISCOP_LOAD_INSN_LENGTH)))
   
(define-primop (code-lit-length (res) (c))
  (asm
   (cps-asm-reglit-insn ctxt MISC res c MISCOP_LOAD_LIT_LENGTH)))

(define-primop (make-code (res) (insn-length lit-length))
  (alloc-size
   #t)
  (asm
   (cps-asm-reglit-insn ctxt MISC 0 insn-length MISCOP_SET_COUNT)
   (cps-asm-reglit-insn ctxt TRAP 0 lit-length TRAPOP_CHECK_ALLOC_CODE)
   (cps-asm-reglit-insn ctxt MISC 0 insn-length MISCOP_SET_COUNT)
   (cps-asm-reglit-insn ctxt MISC res lit-length MISCOP_ALLOC_CODE)
   (cps-asm-reglit-insn ctxt MISC 0 insn-length MISCOP_SET_COUNT)
   (cps-asm-reglit-insn ctxt MISC 0 lit-length MISCOP_INIT_CODE)
   (cps-asm-reglit-insn ctxt MISC 0 (cps-quote #f) MISCOP_FILL)))

;;; Disassembler

;; (define (disfmt fmt op x y z code)
;;   (if (not fmt)
;;       (disfmt "OP %o %x %y %z" op x y z code)
;;       (let ((n (string-length fmt)))
;; 	(let loop ((i 0))
;; 	  (cond ((>= i n) #t)
;; 		((eq? (string-ref fmt i) #\%)
;; 		 (case (string-ref fmt (1+ i))
;; 		   ((#\o)
;; 		    (display op))
;; 		   ((#\x)
;; 		    (display x))
;; 		   ((#\y)
;; 		    (display y))
;; 		   ((#\z)
;; 		    (display z))
;; 		   ((#\v)
;; 		    (display (+ (* 256 y) z)))
;; 		   ((#\w)
;; 		    (display (+ (* 65535 x) (* 256 y) z)))
;; 		   ((#\X)
;; 		    (display "r")
;; 		    (display x))
;; 		   ((#\Y)
;; 		    (if (odd? (quotient op 2))
;; 			(display (code-lit-ref code y))
;; 			(begin
;; 			  (display "r")
;; 			  (display y))))
;; 		   ((#\Z)
;; 		    (if (odd? op)
;; 			(display (code-lit-ref code z))
;; 			(begin
;; 			  (display "r")
;; 			  (display z))))
;; 		   (else
;; 		    (display "?")))
;; 		 (loop (+ i 2)))
;; 		(else
;; 		 (display (string-ref fmt i))
;; 		 (loop (1+ i))))))))

;; (define reglit-fmts
;;   `((,HALT   . "HALT %x %y %z")
;;     (,MOVE   . "MOVE %X %Y")
;;     (,REF    . "REF %X %Y %Z")
;;     (,REFI   . "REFI %X %Y %z")
;;     (,SET    . "SET %X %Y %Z")
;;     (,SETL   . "SETL %L %Y %Z")
;;     (,SETI   . "SETI %X %Y %z")
;;     (,CMP    . "CMP %x %Y %Z")
;;     (,REFU8  . "REFU8 %X %Y %Z")
;;     (,SETU8  . "SETU8 %X %Y %Z")
;;     (,REFU16 . "REFU16 %X %Y %Z")
;;     (,SETU16 . "SETU16 %X %Y %Z")
;;     (,ADD    . "ADD %X %Y %Z")
;;     (,SUB    . "SUB %X %Y %Z")
;;     (,MUL    . "MUL %X %Y %Z")
;;     (,DIV    . "DIV %X %Y %Z")
;;     (,REM    . "REM %X %Y %Z")
;;     (,ADD16  . "ADD16 %X %Y %Z %c")
;;     (,SUB16  . "SUB16 %X %Y %Z %c")
;;     (,MUL16  . "MUL16 %X %Y %Z %c")
;;     (,DIV16  . "DIV16 %X %Y %Z %c")
;;     (,ADD16I . "ADD16I %X %Y %z %c")))

;; (define miscop-fmts
;;   `((,MISCOP_GO               . "GO %Y")
;;     (,MISCOP_ALLOC            . "ALLOC %X %Y")
;;     (,MISCOP_INIT             . "INIT %Y %d")
;;     (,MISCOP_INIT_REC         . "INIT_REC %Y %d")
;;     (,MISCOP_INIT_VEC         . "INIT_VEC %Y %d")
;;     (,MISCOP_FILL             . "FILL %Y %d %c")
;;     (,MISCOP_COPY             . "COPY %d %c")
;;     (,MISCOP_LOAD_DESC        . "LOAD_DESC %X %Y")
;;     (,MISCOP_LOAD_LENGTH      . "LOAD_LENGTH %X %Y")
;;     (,MISCOP_TEST_REC         . "TEST_REC %Y")
;;     (,MISCOP_TEST_VEC         . "TEST_VEC %Y")
;;     (,MISCOP_TEST_DESC        . "TEST_DESC %Y %d")
;;     (,MISCOP_TEST_PAIR        . "TEST_PAIR %Y")
;;     (,MISCOP_LOAD_LENGTH_HALF . "LOAD_LENGTH_HALF %X %Y")
;;     (,MISCOP_ALLOC_BYTES      . "ALLOC_BYTES %Y")
;;     (,MISCOP_TEST_CHAR        . "TEST_CHAR %Y")
;;     (,MISCOP_MAKE_CHAR        . "MAKE_CHAR %Y")
;;     (,MISCOP_CHAR_VALUE       . "CHAR_VALUE %Y")
;;     (,MISCOP_TEST_FIXNUM      . "TEST_FIXNUM %Y")
;;     (,MISCOP_SET_COUNT        . "SET_COUNT %Y")
;;     (,MISCOP_SET_COUNT_HI     . "SET_COUNT_HI %Y %c")
;;     (,MISCOP_GET_COUNT        . "GET_COUNT %X")
;;     (,MISCOP_GET_COUNT_HI     . "GET_COUNT_HI %X")
;;     (,MISCOP_LOAD_INSN_LENGTH . "LOAD_INSN_LENGTH %X %Y")
;;     (,MISCOP_LOAD_LIT_LENGTH  . "LOAD_LIT_LENGTH %X %Y")
;;     (,MISCOP_ALLOC_CODE       . "ALLOC_CODE %X %Y %c")
;;     (,MISCOP_INIT_CODE        . "INIT_CODE %Y %c")))

;; (define trapop-fmts
;;   `((,TRAPOP_CHECK_CALLSIG . "CHECK_CALLSIG %x %Y")
;;     (,TRAPOP_CHECK_ALLOC   . "CHECK_ALLOC %Y")))

;; (define op-fmts
;;   `((,MOVEI        . "MOVEI %X %v")
;;     (,ALLOCI       . "ALLOCI %X %v")
;;     (,INITI        . "INITI %w %d")
;;     (,FILLI        . "FILLI %w %d %c")
;;     (,CHECK_ALLOCI . "CHECK_ALLOCI %w")
;;     (,INIT_VECI    . "INIT_VECI %w %d")
;;     (,BRANCH       . "BRANCH %x %v %c")))

;; (define (disinsn code idx)
;;   (let* ((pos (* 4 idx))
;; 	 (op (code-insn-ref-u8 code (+ pos 3)))
;; 	 (op2 (* 4 (quotient op 4)))
;; 	 (x (code-insn-ref-u8 code (+ pos 2)))
;; 	 (y (code-insn-ref-u8 code (+ pos 1)))
;; 	 (z (code-insn-ref-u8 code (+ pos 0))))
;;     (cond ((= op2 MISC)
;; 	   (disfmt (assq-ref miscop-fmts z) op x y z code))
;; 	  ((= op2 TRAP)
;; 	   (disfmt (assq-ref trapop-fmts z) op x y z code))
;; 	  ((< op 128)
;; 	   (disfmt (assq-ref reglit-fmts op2) op x y z code))
;; 	  (else
;; 	   (disfmt (assq-ref op-fmts op) op x y z code)))))

;; (define (discode code)
;;   (do ((i 0 (1+ i)))
;;       ((= i (code-insn-length code)))
;;     (disinsn code i)
;;     (newline)))

(pk 'asm-vm)
