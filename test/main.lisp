(in-package :cim.test)
(in-suite :cim)

(defparameter *test-root*
  (load-time-value
   (princ-to-string
    (merge-pathnames
     "test/"
     (asdf:system-source-directory :cim-test)))))
(print *test-root*)


(defmacro with-stdout-to-string (&body body)
  `(with-output-to-string (*standard-output*)
     ,@body))

(defun fresh-main (argv)
  (let ((*options* (make-hash-table)))
    (let ((fdefinition (symbol-function 'exit)))
      (unwind-protect
           (progn
             (setf (symbol-function 'exit)
                   (lambda (&rest args)
                     (declare (ignore args))
                     (warn "exited!")))
             (main 0 argv))
        (setf (symbol-function 'exit) fdefinition)))))

(test eval
  (is (string=
       "ABABAP"
       (with-stdout-to-string
         (fresh-main (list "-e" "(princ :ababap)"))))))

(test null
  (signals repl-entered
    (fresh-main nil)))

(test directory
  (is (string=
       *test-root*
       (with-stdout-to-string
         (fresh-main (list "-C" *test-root*
                           "-e" "(princ *default-pathname-defaults*)"))))))

(test load
  (finishes
    ;; load successful no matter what value
    ;; *default-pathname-defaults* is bound to.
    (let ((*default-pathname-defaults* (pathname "/")))
      (fresh-main (list "-C" *test-root*
                        "-f" "scripts/load.lisp"
                        "-e" "nil"))))

  ;; file not found
  (signals file-error
    (fresh-main (list "-f" "no-such-file.lisp"
                      "-e" "nil") ;; specify the nonexistent value
                )))

(test --terminating
  (is (string=
       "T"
       (with-stdout-to-string
         (with-input-from-string (*standard-input* "")
           (fresh-main (list "-e" "(princ (null cim:*argv*))"))))))
  (is (string=
       "T"
       (with-stdout-to-string
         (with-input-from-string (*standard-input* "")
           (fresh-main (list "-e" "(princ (null cim:*argv*))" "--"))))))
  (is (string=
       "-d"
       (with-stdout-to-string
         (with-input-from-string (*standard-input* "")
           (fresh-main (list "-e" "(princ (first cim:*argv*))" "--" "-d")))))))

(test shebang
  ;; shebang
  (is (string=
       "T"
       (with-stdout-to-string
         (with-input-from-string (*standard-input* "")
           ;; This input should not be read.
           ;; Otherwise it means that the stdin-stdout mode is initiated.
           (fresh-main (list "-C" *test-root* "--" "scripts/shebang.lisp"))))))
  ;; without --
  (handler-case 
      (is (string=
           "T"
           (with-stdout-to-string
             (with-input-from-string (*standard-input* "")
               (fresh-main (list "-C" *test-root* "scripts/shebang.lisp"))))))
    (repl-entered (c)
      (5am:fail "repl is entered, which is not expected to happen."))))

(test verbose
  ;; test the verbosity
  ;; verbosity = 1
  (finishes
    (fresh-main (list "-C" *test-root*
                      "-f" "scripts/verbose.lisp"
                      "-v"
                      "-e" "nil")))
  ;; check the verbosity
  (is (string= "1"
               (with-output-to-string (*error-output*)
                 (fresh-main (list "-C" *test-root*
                                   "-f" "scripts/verbose.lisp"
                                   "-v"
                                   "-p" "cim"
                                   "-e" "(princ (opt :verbosity) *error-output*)")))))

  ;; verbosity = 2
  (finishes
    (fresh-main (list "-C" *test-root*
                      "-f" "scripts/verbose.lisp"
                      "-v" "-v"
                      "-p" "cim"
                      "-e" "(princ (opt :verbosity))")))
  ;; check the verbosity
  (is (string= "2"
               (with-output-to-string (*error-output*)
                 (fresh-main (list "-C" *test-root*
                                   "-f" "scripts/verbose.lisp"
                                   "-v" "-v"
                                   "-p" "cim"
                                   "-e" "(princ (opt :verbosity) *error-output*)")))))

  ;; use the combined args, v = 2
  (finishes
    (fresh-main (list "-C" *test-root*
                      "-f" "scripts/verbose.lisp"
                      "-vv"
                      "-e" "nil")))
  ;; check the verbosity
  (finishes
    (is (string= "2"
                 (with-output-to-string (*error-output*)
                   (fresh-main (list "-C" *test-root*
                                     "-f" "scripts/verbose.lisp"
                                     "-vv"
                                     "-p" "cim"
                                     "-e" "(princ (opt :verbosity) *error-output*)")))))))


(test package
  (is (string= "1COMMON-LISP-USER"
               (with-stdout-to-string
                 (fresh-main (list "-C" *test-root*
                                   "-e" "(princ 1)"
                                   "-e" "(princ (package-name *package*))")))))
  (is (string= "CIM"
               (with-stdout-to-string
                 (fresh-main (list "-C" *test-root*
                                   "-p" "cim"
                                   "-e" "(princ (package-name *package*))"))))))

(test main1
  (is (string=
       "HELLO!"
       (with-stdout-to-string
         (fresh-main (list "-C" *test-root*
                           "-f" "scripts/main1.lisp"
                           "-e" "(main1)"))))))

(test version
  (is (string=
       (with-open-file (stream (asdf:system-relative-pathname
                                :cim
                                #p"VERSION"))
         (when stream
           (let ((seq (make-array (file-length stream)
                                  :element-type 'character
                                  :fill-pointer t)))
             (setf (fill-pointer seq) (read-sequence seq stream))
             seq)))
       (with-stdout-to-string
         (handler-case 
             (fresh-main (list "--version"))
           (warning (c)))))))