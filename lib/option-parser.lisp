(in-package :cim.impl)

(defun short-opt-p (opt-string)
  (and (= (length opt-string) 2)
       (char= (aref opt-string 0) #\-)
       (char/= (aref opt-string 1) #\-)))

(defun long-opt-p (opt-string)
  (and (> (length opt-string) 2)
       (string= opt-string "--" :end1 2)))


(defstruct (clause (:constructor clause))
  (long-options nil :type list)
  (short-options nil :type list)
  (aux-options nil :type list)
  (lambda-list nil :type list)
  (doc "" :type string)
  (body nil :type list))

(defun parse-clause (clause)
  (destructuring-bind (options lambda-list . body) clause
    (dolist (designator '(&rest &optional &key &allow-other-keys
                          &aux &body &whole &environment))
      (assert (not (member designator lambda-list)) (lambda-list)
              "option lambda-list should not contain ~a." designator))
    (clause :long-options (remove-if-not #'long-opt-p options)
            :short-options (remove-if-not #'short-opt-p options)
            :aux-options (remove-if (lambda (o) (or (long-opt-p o) (short-opt-p o)))
                                    options)
            :lambda-list lambda-list
            :doc (if (stringp (car body)) (car body) "")
            :body (if (stringp (car body)) (cdr body) body))))

(defun clause-options (clause)
  (append (clause-long-options clause)
          (clause-short-options clause)
          (clause-aux-options clause)))

(defun clause-help-title (clause)
  (format nil "~{~A~^, ~} ~{~A~^ ~}"
          (clause-options clause)
          (clause-lambda-list clause)))

;; TODO: align the table correctly
;; consider the given help message

;; dispatcher compilation

(defun clause-flag-match-condition (flag-var clause)
  (assert (symbolp flag-var) nil)
  `(or ,@(mapcar (lambda (opt) `(string= ,opt ,flag-var)) (clause-options clause))))

(defun make-dispatcher-function (clauses)
  (let ((argv (gensym "ARGV"))
        (head (gensym "HEAD"))
        (rest (gensym "REST"))
        (crest (gensym "CREST")))
  `(lambda (,argv)
     (destructuring-bind (,head . ,rest) ,argv
       (cond
         ,@(mapcar
            (lambda (c)
              `(,(clause-flag-match-condition head c)
                 (destructuring-bind (,@(clause-lambda-list c) . ,crest) ,rest
                   ,@(clause-body c)
                   (values ,crest t))))
            clauses)
         ((string= ,head "--") (values ,rest nil)))))))

;; help message aggregation

(defun generate-help-message (clauses)
  (let* ((titles (mapcar #'clause-help-title clauses))
         (max (reduce #'max titles :key #'length))
         (docs (mapcar #'clause-doc clauses)))
    (with-output-to-string (s)
      (loop
         for title in titles
         for doc in docs
         do (format s "~VA ~A~%" max title doc)))))

;; runtime dispatch

(defun %parse-options-rec (argv dispatcher)
  (multiple-value-bind (result dispatched-p) (funcall dispatcher argv)
    (if dispatched-p
        (%parse-options-rec result dispatcher)
        result)))

(defun make-parse-options (argv clauses)
  `(%parse-options-rec
    ,argv
    ,(make-dispatcher-function
      (mapcar #'parse-clause
              (append clauses
                      `((("-h" "--help") ()
                         (write-string ,(generate-help-message clauses))
                         (return))))))))

(defmacro parse-options (argv &rest clauses)
  "Parse `ARGV' follwoing `CLAUSES'. The clauses should be
((options) (parameters)
  \"docstring \"
   body)
where
`OPTIONS'    are either strings which start with \"-\" followed by a single
             character (short option) or \"--\" followed by string (long option).
`PARAMETERS' are symbols which will be bound given arguments.
`DOCSTRING'  is string which explain the option. This is used for `--help'.
`BODY'       is evaluated as an implicit progn under the environment where
             `PARAMETERS' are bound to the values given in the command arguments.

If \"--\" is found, immidiately exit from this macro.
The return value is the rest of `ARGV'.
You can access to the variable `GENERATED-HELP' which contains help string.
Example:
(defvar foo)
(parse-options *argv*
  ((\"--foo\" \"-f\") ()
   \"set foo\"
   (setf foo t))
  ((\"--bar\") (arg)
   \"do something with `ARG'\"
   (do-something-with arg)))

The predefined option is
((\"-h\" \"--help\") ()
\"\"
 (write-string generated-help)
 (return)).
You can override \"-h\" and \"--help\" to controll help printing.
 "
  `(make-parse-options ,argv ,clauses))


