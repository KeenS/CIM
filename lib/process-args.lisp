
(in-package :cim)

;;;; implementation strategy --
;; 
;; *raw-argv* is parsed sequentially.
;; Each time, the *raw-argv* is chopped off its head, and the
;; body of matching clause (e.g. `(compile-file file)') are
;; stored in *hooks* as a zero-arg closure
;; (e.g. `(lambda () (compile-file file))').

;; the stored closures should be manually executed afterwards.

(defun process-args ()
  (multiple-value-setq (*argv* *hooks*)
    (parse-options *raw-argv*
      ;; parse the args, stores the processing hooks into *hooks*.
      ;; hooks (zero-arg lambda) should later be run individually.
      ;;
      (("-c" "--compile") (file)
       "compile FILE."
       (compile-file file))

      (("-C") (dir)
       "set *default-pathname-defaults* to DIR."
       (setf *default-pathname-defaults*
             (if (char= #\/ (elt dir 1))
                 (pathname dir)
                 (merge-pathnames (pathname dir)))))

      (("-d" "--debug") ()
       "set debugging flags (push :debug into *features*)"
       (push :debug *features*))

      (("-e" "--eval") (sexp)
       "Evaluates a one-line script.
Once -e option is specified, [programfile] is ignored.
Several -e's are evaluated individually, and in the given order as specified.
For each time the evaluation is performed,
the package is reset to the default package `cl-user'.
The default package can be modified via -p option.
Note that, since the option processing is done sequentially,
you should specify the package BEFORE specifying a script to run.
"
       (let ((*package* (or (opt :package) #.(find-package :common-lisp-user))))
         ;; the package is protected and do not interfere the later evaluation
         (eval sexp)))

      (("-p" "--package") (package)
       "Modifies the default package, initially cl-user.
All -e commands are affected after this option."
       (setf (opt :package) (find-package (string-upcase package))))

      (("-f" "--load") (file)
       "load the FILE"
       (load file))

      (("-i") (ext)
       "Edit the files specified in the remainder of *argv* in place,
 that is, take the file as input and write the output to the same file.
Using this option assumes the command takes filenames as arguments,
and the same processing is performed over those files.
There are two such cases:

  cl <flags> -- <script>.lisp [inputfile]...
  cl <flags> -e '(do-something *argv*)' -- [inputfile]...

The old input file will be backed up with the extension EXT.
For exammple, 'cl ... -i .old ... x.data' results in two files named
'x.data.old' and the modified file 'x.data'."
       (setf (opt :in-place-backup-extention) ext))

      (("-l") (library)
       "quickload the LIBRARY"
       (ensure-quicklisp)
       ;; speed does not matter.
       ;; ideally use of (intern ...) should be avoided.
       (funcall (symbol-function
                 (read-from-string "ql:quickload"))
                library))

      (("-L") (library)
       "quickload and use-package the LIBRARY"
       (ensure-quicklisp)
       (funcall (symbol-function
                 (read-from-string "ql:quickload"))
                library)
       ;; use-package accepts string designator
       (use-package (string-upcase library)))

      (("-r" "--repl") ()
       "run repl"
       (setf (opt :repl) t))

      (("-q" "--no-init") ()
       "do not load $CIM_HOME/init.lisp"
       (setf (opt :no-init) t))

      (("-Q" "--quit") ()
       "quit after processing all supplied commands"
       (setf (opt :quit) t))

      (("--no-rl") ()
       "do not use rlwrap. This is effective only when --repl is specified"
       )

      (("--no-right") ()
       "do not display right prompt. This is effective only when --repl is specified"
       (setf (opt :no-right) t))

      (("--no-color") ()
       "do not use color. This is effective only when --repl is specified"
       (setf (opt :no-color) t))

      (("-v" "--version") ()
       "print the version of cim"
       (write-line (version))
       (exit)))))