(in-package #:coalton-impl/typechecker)

;;;
;;; Type predicates
;;;

(defstruct
    (ty-predicate
     (:constructor ty-predicate (class types)))
  "A type predicate indicating that TYPE is of the CLASS"
  (class (required 'class) :type symbol  :read-only t)
  (types (required 'types) :type ty-list :read-only t))

(defmethod make-load-form ((self ty-predicate) &optional env)
  (make-load-form-saving-slots
   self
   :slot-names '(class types)
   :environment env))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type ty-predicate))

(defun ty-predicate-list-p (x)
  (and (alexandria:proper-list-p x)
       (every (lambda (b) (typep b 'ty-predicate)) x)))

(deftype ty-predicate-list ()
  "A list of type predicates"
  `(satisfies ty-predicate-list-p))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type ty-predicate-list))

;;;
;;; Qualified types
;;;

(defstruct
    (qualified-ty
     (:constructor qualified-ty (predicates type)))
  (predicates (required 'predicates) :type ty-predicate-list :read-only t)
  (type       (required 'type)       :type ty                :read-only t))

(defmethod make-load-form ((self qualified-ty) &optional env)
  (make-load-form-saving-slots
   self
   :slot-names '(predicates type)
   :environment env))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type qualified-ty))

(defun qualify (predicates type)
  "Qualify TYPE with PREDICATES"
  (declare (type ty type)
           (type ty-predicate-list predicates)
           (values qualified-ty))
  (qualified-ty predicates type))


;;;
;;; Methods
;;;

(defmethod apply-substitution (subst-list (type ty-predicate))
  (declare (type substitution-list subst-list)
           (values ty-predicate))
  (ty-predicate (ty-predicate-class type)
                      (apply-substitution subst-list (ty-predicate-types type))))

(defmethod type-variables ((type ty-predicate))
  (type-variables (ty-predicate-types type)))

(defmethod instantiate (types (type ty-predicate))
  (ty-predicate (ty-predicate-class type)
                      (instantiate types (ty-predicate-types type))))


(defmethod apply-substitution (subst-list (type qualified-ty))
  (declare (type substitution-list subst-list))
  (qualified-ty (apply-substitution subst-list (qualified-ty-predicates type))
                      (apply-substitution subst-list (qualified-ty-type type))))

(defmethod type-variables ((type qualified-ty))
  (remove-duplicates
   (append (type-variables (qualified-ty-predicates type))
           (type-variables (qualified-ty-type type)))
   :test #'equalp))

(defmethod instantiate (types (type qualified-ty))
  (qualified-ty (instantiate types (qualified-ty-predicates type))
                      (instantiate types (qualified-ty-type type))))

(defmethod kind-of ((type qualified-ty))
  (kind-of (qualified-ty-type type)))

(defmethod function-type-p ((type qualified-ty))
  (function-type-p (qualified-ty-type type)))

(defmethod function-return-type ((type qualified-ty))
  (qualify nil (function-return-type (qualified-ty-type type))))

(defmethod function-type-arguments ((type qualified-ty))
  (function-type-arguments (qualified-ty-type type)))

;;;
;;; Pretty printing
;;;

(defun pprint-predicate (stream predicate &optional colon-p at-sign-p)
  (declare (type stream stream)
           (type ty-predicate predicate)
           (ignore colon-p)
           (ignore at-sign-p)
           (values ty-predicate))
  (format stream "~S ~{~A~^ ~}"
          (ty-predicate-class predicate)
          (ty-predicate-types predicate))
  predicate)

(set-pprint-dispatch 'ty-predicate 'pprint-predicate)


(defun pprint-qualified-ty (stream qualified-ty &optional colon-p at-sign-p)
  (declare (ignore colon-p)
           (ignore at-sign-p))
  (cond
    ((= 0 (length (qualified-ty-predicates qualified-ty)))
     (format stream "~A" (qualified-ty-type qualified-ty)))

    ((= 1 (length (qualified-ty-predicates qualified-ty)))
     (format stream "~A" (first (qualified-ty-predicates qualified-ty)))
     (write-string (if *coalton-print-unicode*
                          " ⇒ "
                          " => ")
                   stream)
     (format stream "~A" (qualified-ty-type qualified-ty)))
    (t
     (dolist (pred (qualified-ty-predicates qualified-ty))
       (write-string "(" stream)
       (format stream "~A" pred)
       (write-string ") " stream))
     (write-string (if *coalton-print-unicode*
                          "⇒ "
                          "=> ")
                   stream)
     (format stream "~A" (qualified-ty-type qualified-ty))))
  nil)

(set-pprint-dispatch 'qualified-ty 'pprint-qualified-ty)
