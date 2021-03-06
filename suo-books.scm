;;; Books, sections, and pages.

;; Books contain the bulk of the code in a Suo system, in a literate
;; programming kind of way that allows for interactive and incremental
;; development.
;;
;; The basic concept is that of a SECTION: A section contains some
;; descriptive text, a set of properties, a list of expressions, and a
;; list of sub-sections.  Sections form a tree: a section can only be
;; a sub-section of at most one other section.
;;
;; A BOOK is simply a top-level section.  A PAGE is a section with no
;; sub-sections.
;;
;; The text of a section is a general commentary on the code that
;; follows.
;;
;; The properties of a section are used to determine certain defaults
;; for its sub-sections.  The most common properties are 'directory',
;; which specifies which directory should be current when expressions
;; are compiled, and 'open', which determines which directories are
;; opened.
;;
;; The list of expressions contain the actual code of the section.
;; Each expression is either a top-level definition or a action.
;;
;; The sub-sections inherit the properties of their parent, but are
;; otherwise independent.  The tree-structure of a book is mostly
;; useful for guiding the reader.  Typically, sections either have
;; expressions, or sub-sections, but not both.
;;
;; A section can actually contain multiple versions of its content.
;; Right now, only two versions with a specific meaning are allowed:
;; the 'current' version is the one that has been committed most
;; recently, and the 'proposed' version is the one waiting to be
;; comitted.  Preparing a new proposed version of one or more sections
;; and then committing them is the way to make changes to a book.
;;
;; The rules for what happens when you commit a section are designed
;; so that you can commit a whole book in one go and have things work.
;;
;; Committing a section will include all its direct and indirect
;; sub-sections in the commit that have a proposed version.
;;
;; This set of section is committed in batches, so that macros are
;; available when they are used.  From all sections that are to be
;; committed, all sections are selected for the first batch that do
;; not reference a macro that is defined by one of the sections in the
;; commit set.  When there is no selectable section, there is a cycle
;; between macros.  This is not fatal, but the user needs to reduce
;; the committ set so that the cycle is not contained within it.  A
;; cycle that is entirely contained in one section can not be broken
;; this way and must be avoided.
;;
;; Once the first batch has been selected, it is committed (see
;; below).  Then the procedure starts over with the remaining
;; sections.
;;
;; In order to perform this sorting of sections, their expressions
;; must be analyzed to determine which macros they will define and
;; which of these names they will use.  This is mildly
;; straightforward, but the process must deal with the possibility
;; that there are macros that expand into top-level definitions.
;;
;; Commiting a batch happens in three steps: declaring, compiling, and
;; installing.
;;
;; First, all top-level definitions are declared: a entry is created
;; for them in the directory that has the correct type, etc, but a
;; useless value.  Existing entries are check for compatibility and
;; updated for the new definition.  Thus, all top-level definitions
;; are visible already during the compilation step.  When there is an
;; error in the middle of this step (such as a existing definition
;; that can not be compatibly updated), processing stops, but all
;; already created or updated entries are left in place.
;;
;; Then, the value expressions of all top-level definitions and the
;; actions are compiled (but not evaluated).
;;
;; When the this compilation has succeeded, the compiled expressions
;; are evaluated, which results in the new values finally being entered
;; into the directories.
;;
;; When a old entry already exists for a top-level definition,
;; different things happen depending on the type of the definition.
;;
;; When updating a variable, nothing happens.  In particular, the
;; default value given in the new definition is ignored.  The
;; expression for it is compiled, but not evaluated.
;;
;; When updating a function, the function is changed 'in-place' to the
;; new one, without losing the identity of the old function.  That is,
;; if you have stored the old function object in some data structure,
;; that old function will cange its behavior to that of the new
;; function.
;;
;; When updating a macro, the new transformer replaces the old.  No
;; automatic recompilation of users of the macro takes place.
;;
;; When updating a record type, all instances of the old type are
;; transformed into instances of the new type.
;;
;; The actions are simply evaluated inbetween handling the top-level
;; definitions, according to their place in the section expressions.
;; Their result values are ignored.
;;
;; If the expressions of the current batch have been executed
;; successfully, the proposed versions of the sections become the
;; current versions.
;;
;;
;; When compiling the section expressions, the environment needs to be
;; defined.  For this, a current directory and a list of open
;; directories are found by going up the section tree and looking for
;; 'directory', 'open', and 'open-also' properties.
;;
;; The current directory is determined by the first 'directory'
;; property encountered on the way up to the top-level section.
;;
;; The list of open directories starts out empty, and the directories
;; listed in the 'open-also' properties are collected while going up.
;; Properties that are farther away from the current section appear
;; further towards the start of the list.  When a 'open' property is
;; encountered, it is treated as a 'open-also' property but collecting
;; stops at that level of the section tree.
;;
;; The names of the new definitions are interpreted relative to the
;; current directory.  When remembering these names, their full
;; absolute pathnames are stored, so the you can cleanly switch
;; current directories from one version to the next.
;;
;; The list of sub-sections and the parent reference of a section are
;; also versioned.  When commiting a set of sections, the set must be
;; consistent with respect to the tree of sections: when the parent of
;; a section changes, the old and new parents must be part of the
;; commit set.
;;
;; For example, when moving section S from P1 to P2, the proposed
;; sub-sections of both P1 and P2 are modified to reflect the change
;; and the change can only be committed when all of S, P1 and P2 are
;; part of the commit set.
;;
;;
;; For interchange with the outside world, sections can be serialized
;; in a line-orented format.
;;
;; The different parts of a section (description, properties,
;; expressions) are introduced by a header lines starting with "@*",
;; "@=", and "@@" respectively.  The description part is mandatory,
;; even when it is empty, but the properties and expression parts can
;; be ommitted.
;;
;; A section ends when the next one starts.  The tree-structure of
;; sections is expressed by specifying the depth of a section with the
;; number of stars in its "@*" header.
;;
;; The description of a section can include a title.  This title is
;; written on the header line directly.
;;
;; A section can have a unique identifier in its serialized form.
;; This identifier is used to determine which section to update when
;; reading in a serialized section.  When there is no identifier, a
;; new section is created.
;;
;; Thus, a section on level two with a sub-section might look like
;; this:
;;
;;     @**    An example section                              [@1567]
;;
;;     ;; This is the description.  It is written as a comment to make
;;     ;; editing with Emacs easier.
;;
;;     @=
;;     (open-also /web/bokeh)
;;
;;     @@
;;
;;     (define (foo) 
;;       (create-bokeh 1 2 3))
;;
;;     @***   A sub-section without description                [@213]
;;     @@
;;
;;     (define bar (foo))
;;
;;
;; The two stars on the first line signify that this section is at
;; level two of the book, and the three stars make "A sub-section" a
;; sub-section of it.
;;
;; The "[identifier]" parts of the header lines contain the unique
;; identifiers.  They have no significance except to associate
;; sections with their origins when the are read back in.  Once a
;; section has acquired an identifier, it never changes.
;;
;; In addition, a "@q" at the beginning of a line ends the current
;; section and stops parsing the section format.
;;
;; XXX - in the future, sections should also remember which
;;       definitions of other sections they use, so that smart
;;       re-compilations can be triggered when macros change etc.
;;
;; XXX - more version control things should be defined: logs, diffing,
;;       branching, merging,

(define-record section-content
  :prefix scont
  :slots (description
	  (properties '())
	  expressions
	  (parent #f) (children '()))
  :constructor (section-content description expressions))

(define (scont-copy c)
  (let ((c2 (section-content (scont-description c)
			     (scont-expressions c))))
    (set! (scont-properties c2) (scont-properties c))
    (set! (scont-parent c2) (scont-parent c))
    (set! (scont-children c2) (scont-children c))
    c2))

(define-record section
  :slots (id (committed #f) (proposed #f) (errors #f) (defined-names '()))
  :constructor (section id committed))

(define (section-proposed! s)
  (if (not (section-proposed s))
      (set! (section-proposed s) (scont-copy (section-committed s))))
  (section-proposed s))

(define sections (make-hashq-table 31))

(define (all-sections)
  (hashq-fold '() (lambda (c r) (cons (cdr c) r)) sections))

(define-function next-section-id
  (let ((i 0))
    (lambda ()
      (set! i (1+ i))
      (let ((id (string->symbol (string-append "@" (number->string i)))))
	(if (not (hashq-ref sections id))
	    id
	    (next-section-id))))))

(define (find-section id)
  (if (not id)
      (find-section (next-section-id))
      (or (hashq-ref sections id)
	  (let ((s (section id (section-content "" ""))))
	    (hashq-set! sections id s)
	    s))))

(define (section-tip s)
  (or (section-proposed s)
      (section-committed s)))

(define (section-parent s)
  (scont-parent (section-tip s)))

(define (section-children s)
  (scont-children (section-tip s)))

(define (section-description s)
  (scont-description (section-tip s)))

(define (section-properties s)
  (scont-properties (section-tip s)))

(define (section-expressions s)
  (scont-expressions (section-tip s)))

(define (section-depth s)
  (if (section-parent s)
      (1+ (section-depth (section-parent s)))
      1))

(define (section-inherited-property s prop)
  (or (assq-ref (section-properties s) prop)
      (and (section-parent s)
	   (section-inherited-property (section-parent s) prop))))

(define (section-directory s)
  (and=> (section-inherited-property s 'directory) car))

(define (section-open-directories s)

  (define (open-dirs s tail)
    (let* ((opens (assq-ref (section-properties s) 'open))
	   (open-alsos (or (assq-ref (section-properties s) 'open-also) '()))
	   (res (append (if opens opens '()) open-alsos tail)))
      (if (or opens
	      (not (section-parent s)))
	  res
	  (open-dirs (section-parent s) res))))

  (open-dirs s '()))
	  
(define (write-section s)
  ;; time for some routines for formatted output, I s'pose...

  (define (display-multi len x)
    (do ((i len (1- i)))
	((= i 0))
      (display x)))

  (define (display-with-newline str)
    (display str)
    (let ((len (string-length str)))
      (if (or (zero? len)
	      (not (eq? (string-ref str (1- len)) #\newline)))
	  (newline))))

  (define (write-one s)
    (let* ((depth (section-depth s))
	   (desc (section-description s))
	   (desc-len (string-length desc))
	   (title-len (or (string-index desc #\newline)
			  (string-length desc))))
      (display "@")
      (display-multi depth #\*)
      (display-multi (max (- 6 depth) 1) #\space)
      (display (substring (section-description s) 0 title-len))
      (display-multi (max (- 78 1 depth (max (- 6 depth) 1) 
			     title-len
			     5 (string-length 
				(symbol->string (section-id s))) 1)
			  1)
		     #\space)
      (display " [")
      (write (section-id s))
      (display " ")
      (display (if (section-proposed s) "*" "-"))
      (display (if (section-errors s) "!" "-"))
      (display "]")
      (if (< title-len desc-len)
	  (display-with-newline (substring desc title-len (string-length desc)))
	  (newline)))
    
    (cond ((not (null? (section-properties s)))
	   (display "=\n")
	   (for-each (lambda (p)
		       (write p)
		       (newline))
		     (section-properties s))
	   (newline)))
    
    (cond ((not (zero? (string-length (section-expressions s))))
	   (display "-\n")
	   (display-with-newline (section-expressions s))))
    
    (cond ((section-errors s)
	   (display "!\n")
	   (display-with-newline (section-errors s))
	   (newline)))

    (for-each write-one (section-children s)))

  (write-one s)
  (display "@q\n"))

(define (section-propose-field! s accessor value)
  (if (not (equal? value (accessor (section-tip s))))
      (set! (accessor (section-proposed! s)) value)))

(define (section-propose-description! s desc)
  (section-propose-field! s scont-description desc))

(define (section-propose-properties! s props)
  (section-propose-field! s scont-properties props))

(define (section-propose-expressions! s exprs)
  (section-propose-field! s scont-expressions exprs))

(define (section-propose-parent! s parent)
  (if (not (eq? parent (and=> (section-committed s) scont-parent)))
      (begin
	(let ((old (section-parent s)))
	  (if old
	      (set! (scont-children (section-proposed! old))
		    (delq1 s (scont-children (section-proposed! old))))))
	(set! (scont-parent (section-proposed! s)) parent)
	(if parent
	    (set! (scont-children (section-proposed! parent))
		  (append (scont-children (section-proposed! parent))
			  (list s)))))))

(define (string-prefix? str pfx)
  (and (>= (string-length str) (string-length pfx))
       (equal? (substring str 0 (string-length pfx)) pfx)))

(define (read-text-line)
  (let ((buf (make-string 256)))
    (let loop ((i 0))
      (let ((ch (input-char (current-input-port))))
	(cond ((eof-object? ch)
	       (if (zero? i)
		   ch
		   (substring buf 0 i)))
	      (else
	       (string-set! buf i ch)
	       (if (eq? ch #\newline)
		   (substring buf 0 (1+ i))
		   (loop (1+ i)))))))))

(define (read-nonblank-text-line)
  (let loop ()
    (let ((line (read-text-line)))
      (cond ((eof-object? line)
	     line)
	    ((or (zero? (string-length line))
		 (eq? (string-ref line 0) #\newline))
	     (loop))
	    (else
	     line)))))

(define (read-forms-from-string str)
  (let ((p (make-string-input-port str)))
    (let loop ((forms '()))
      (let ((f (read p)))
	(if (eof-object? f)
	    (reverse forms)
	    (loop (cons f forms)))))))

(define (parse-section-header str)
  (let ((pos 0)
	
	(depth 0)
	(title "")
	(id #f))

    (define (invalid)
      (error "invalid section header: " str))

    (define (get)
      (cond ((< pos (string-length str))
	     (set! pos (1+ pos))
	     (string-ref str (1- pos)))
	    (else
	     (set! pos (1+ pos))
	     the-eof-object)))

    (define (putback)
      (set! pos (1- pos)))

    (define (skipws)
      (let ((ch (get)))
	(if (whitespace? ch)
	    (skipws)
	    (putback))))

    (if (not (eq? (get) #\@))
	(invalid))

    (let loop ((d 0))
      (let ((ch (get)))
	(cond ((eq? ch #\*)
	       (loop (1+ d)))
	      (else
	       (putback)
	       (set! depth d)))))

    (skipws)

    (let ((t-pos pos))
      (let loop ((last-nonws pos))
	(let ((ch (get)))
	  (cond ((or (eof-object? ch)
		     (eq? ch #\[))
		 (putback)
		 (if (< t-pos last-nonws)
		     (set! title (substring str t-pos last-nonws))))
		(else
		 (loop (if (not (whitespace? ch)) pos last-nonws)))))))
    
    (if (eq? (get) #\[)
	(let ((id-pos pos))
	  (let loop ()
	    (let ((ch (get)))
	      (cond ((or (eof-object? ch)
			 (eq? ch #\]))
		     (putback)
		     (set! id (read (make-string-input-port 
				     (substring str id-pos pos)))))
		    (else
		     (loop)))))))

    (values depth title id)))

(define (read-section)
		 
  (define (read-sections header parents last-section top-section)
    (cond ((or (eof-object? header)
	       (string-prefix? header "@q"))
	   top-section)
	  (else
	   (let-values1 (depth title id (parse-section-header header))
	     (let ((sec (find-section id)))

	       (let ((new-parents
		      (cond ((or (not last-section)
				 (= depth (section-depth last-section)))
			     parents)
			    ((< depth (section-depth last-section))
			     ;; moving up
			     (let ((delta (- (section-depth last-section)
					     depth)))
			       (if (< delta (length parents))
				   (list-tail parents delta)
				   '())))
			    ((> depth (section-depth last-section))
			     ;; moving down
			     (or (= depth (1+ (section-depth last-section)))
				 (error "improper sub-section nesting: "
					header))
			     (cons last-section parents)))))

		 (cond ((null? new-parents)
			(or (not last-section)
			    (error "more than one top section"))
			(or (= (section-depth sec) depth)
			    (error "improper section depth: " header)))
		       (else
			(section-propose-parent! sec (car new-parents))))
		 
		 (read-sections (read-content sec title) new-parents
				sec (or top-section sec))))))))

  (define (chunk-header? line)
    (or (string-prefix? line "@")
	(equal? line "=\n")
	(equal? line "-\n")
	(equal? line "!\n")))

  (define (read-chunk)
    (let loop ((text ""))
      (let ((line (read-text-line)))
	(cond ((or (eof-object? line)
		   (chunk-header? line))
	       (values text line))
	      (else
	       (loop (string-append text line)))))))
    
  (define (read-content sec title)
    (define (gobble-desc)
      (let-values1 (desc header (read-chunk))
        (section-propose-description! sec (string-append title "\n" desc))
	header))
    (define (gobble-props header)
      (if (equal? header "=\n")
	  (let-values1 (props header (read-chunk))
	    (section-propose-properties! sec (read-forms-from-string props))
	    header)
	  (begin
	    (section-propose-properties! sec '())
	    header)))
    (define (gobble-expressions header)
      (if (equal? header "-\n")
	  (let-values1 (exprs header (read-chunk))
	    (section-propose-expressions! sec exprs)
	    header)
	  (begin
	    (section-propose-expressions! sec "")
	    header)))
    (define (gobble-errors header)
      (if (equal? header "!\n")
	  (let-values1 (exprs header (read-chunk))
	    header)
	  header))
    (gobble-errors (gobble-expressions (gobble-props (gobble-desc)))))

  (define (gobble-until-end)
    (let loop ()
      (let ((line (read-text-line)))
	(if (not (or (eof-object? line)
		     (string-prefix? line "@q")))
	    (loop)))))

  (with-error-handler
   (lambda args
     (gobble-until-end)
     (apply error args))
   (lambda ()
     (read-sections (read-nonblank-text-line) '() #f #f))))

(define (read-section-and-write)
  (write-section (read-section)))

(define (read-forms-from-string str)
  (let ((p (make-string-input-port str)))
    (let loop ((res '()))
      (let ((f (read p)))
	(cond ((eof-object? f)
	       (reverse res))
	      (else
	       (loop (cons f res))))))))

(define (eval-string str)
  (eval (cons 'begin (read-forms-from-string str))))

(define (ensure-directory path)
  (if (not (and=> (and=> (lookup* path) entry-value) directory?))
      (make-directory path)))

(define (call-with-current-directory path proc)
  (if path
      (let* ((abs (pathname-concat (current-directory-path) path))
	     (e (lookup* abs)))
	(cond ((directory? (entry-value e))
	       (call-p current-directory e
		       (lambda ()
			 (call-p current-directory-path abs
				 proc))))
	      (else
	       (error "not a directory: " abs))))
      (proc)))

(define-macro (with-current-directory path . body)
  `(call-with-current-directory ,path (lambda () ,@body)))

(define (call-with-open-directories paths proc)
  (let ((dirs (map (lambda (p)
		     (let ((d (and=> (lookup* p) entry-value)))
		       (or (directory? d)
			   (error "not a directory: " p))
		       d))
		   paths)))
    (call-p open-directories dirs proc)))

(define-macro (with-open-directories paths . body)
  `(call-with-open-directories ,paths (lambda () ,@body)))

(define (eval-section s)
  (call-cc
   (lambda (exit)
     (with-error-handler
      (lambda args
	(let ((p (make-string-output-port)))
	  (call-p current-output-port p
		  (lambda ()
		    (apply display-error args)))
	  (set! (section-errors s) (get-string-output-port-string p))
	  (exit #f)))
      (lambda ()
	(set! (section-errors s) #f)
	(let ((dir (section-directory s)))
	  (or (pathname-absolute? dir)
	      (error "must be absolute: " dir))
	  (ensure-directory dir)
	  (with-current-directory dir
	    (with-open-directories (section-open-directories s)
	      (let ((form (cons 'begin (read-forms-from-string 
					(section-expressions s)))))
		(eval form)
		(map (lambda (n) (pathname-concat dir n))
		     (defined-names form)))))))))))

(define (map-append proc list)
  (apply append (map proc list)))

(define (and-map proc list)
  (cond ((null? list)
	 #t)
	((null? (cdr list))
	 (proc (car list)))
	(else
	 (and (proc (car list))
	      (and-map proc (cdr list))))))

(define (top-level-forms form)
  (let ((form (macroexpand form)))
    (if (and (pair? form)
	     (eq? (car form) :begin))
	(map-append (lambda (f)
		      (top-level-forms f))
		    (cdr form))
	(list form))))

(define (defined-names form)
  (map-append (lambda (f)
		(if (and (pair? f)
			 (memq (car f)
			       '(:define
				 :define-function
				 :define-record-type
				 :define-macro)))
		    (list (cadr f))
		    '()))
	      (top-level-forms form)))

(define (commit-section s force)

  (define (set-difference-equal l1 l2)
    "Return elements from list L1 that are not in list L2."
    (let loop ((l1 l1) (result '()))
      (cond ((null? l1) (reverse result))
	    ((member (car l1) l2) (loop (cdr l1) result))
	    (else (loop (cdr l1) (cons (car l1) result))))))
  
  (define (commit-one s)
    (if force
	(section-proposed! s))
    (and (or (not (section-proposed s))
	     (let ((names (eval-section s)))
	       (if names
		   (let ((obsolete-names (set-difference-equal 
					  (section-defined-names s)
					  names)))
		     (set! (section-committed s) (section-proposed s))
		     (set! (section-defined-names s) names)
		     (for-each /boot/rm obsolete-names)
		     (set! (section-proposed s) #f)
		     #t)
		   #f)))
	 (and-map commit-one (section-children s))))
  
  (commit-one s))

(define (read-commit-write-section force)
  (let ((s (read-section)))
    (commit-section s force)
    (write-section s)))

(define (get-section id)
  (write-section (find-section id)))

(define (put-section)
  (write-section (read-section)))

(define (fix-section sec)
  (if (eq? (section-defined-names sec) #t)
      (begin
	(pk 'fixing (section-id sec))
	(set! (section-defined-names sec) '()))))

(define (fix-all-sections)
  (for-each fix-section (all-sections)))

@*     Foo                                                           [@123 --]

Hi, this is a top-level section, aka, a book.  This part of it is its
description.  It ends at the "=" marker, after which its properties
are listed.  The code of this section would follow after the "-"
marker, if it would have any, which it doesn't.

=
(directory /test)
(open /boot)

@**    Barbar                                                         [@54 --]

A sub-section.  This one has some code but no sub-sections of its own.
Thus, it's a 'page'.

-
(define (baaboobaz2) 16)

@**    Bar2                                                           [@55 --]
-
(define bar5 12)

@***   Baz                                                            [@56 --]
Hep
