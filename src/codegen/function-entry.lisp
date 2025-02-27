(in-package #:coalton-impl/codegen)

;; We need to evaluate this early so the macro below can inline calls
(eval-when (:load-toplevel)
  (defstruct function-entry
    (arity    (required 'arity)    :type fixnum   :read-only t)
    (function (required 'function) :type function :read-only t)
    (curried  (required 'curried)  :type function :read-only t))
  #+(and sbcl coalton-release)
  (declaim (sb-ext:freeze-type function-entry)))

(defvar *function-constructor-functions* (make-hash-table))
(defvar *function-application-functions* (make-hash-table))

(defmacro define-function-macros ()
  (labels ((define-function-macros-with-arity (arity)
             (declare (type fixnum arity))
             (let ((constructor-sym (alexandria:format-symbol t "F~D" arity))
                   (application-sym (alexandria:format-symbol t "A~D" arity))
                   (sub-application-sym (alexandria:format-symbol t "A~D" (1- arity)))
                   (function-sym (alexandria:make-gensym "F"))
                   (applied-function-sym (alexandria:make-gensym "F"))
                   (arg-syms (alexandria:make-gensym-list arity)))

               (labels ((build-curried-function (args)
                          (if (null (car args))
                              `(funcall ,function-sym ,@arg-syms)
                              `(lambda (,(car args)) ,(build-curried-function (cdr args)))))
                        (build-curried-function-call (fun args)
                          (if (= 1 arity)
                              `(funcall ,fun ,(car args))
                              `(,sub-application-sym (funcall ,fun ,(car args)) ,@(cdr args)))))

                 ;; NOTE: Since we are only calling these functions
                 ;; from already typechecked coalton, we can use the
                 ;; OPTIMIZE flags to remove type checks.
                 `(progn
                    (declaim (inline ,application-sym))
                    (defun ,application-sym (,applied-function-sym ,@arg-syms)
                      (declare (optimize (speed 3) (safety 3))
                               (type (or function function-entry) ,applied-function-sym)
                               (values t))
                      (etypecase ,applied-function-sym
                        (function
                         ,(build-curried-function-call applied-function-sym arg-syms))
                        (function-entry
                         (if (= (the fixnum (function-entry-arity ,applied-function-sym)) ,arity)
                             (funcall (function-entry-function ,applied-function-sym)
                                      ,@arg-syms)
                             ,(build-curried-function-call `(function-entry-curried ,applied-function-sym) arg-syms)))))
                    (setf (gethash ,arity *function-application-functions*) ',application-sym)

                    (declaim (inline ,constructor-sym))
                    (defun ,constructor-sym (,function-sym)
                      (declare (type (function ,(loop :for i :below arity :collect 't) t) ,function-sym)
                               (optimize (speed 3) (safety 0))
                               (values function-entry))
                      (make-function-entry
                       :arity ,arity
                       ;; Store a reference to the original function for full application
                       :function ,function-sym
                       ;; Build up a curried function to be called for partial application
                       :curried ,(build-curried-function arg-syms)))
                    (setf (gethash ,arity *function-constructor-functions*) ',constructor-sym))))))
    `(progn
       ,@(loop :for i :of-type fixnum :from 1 :below 10
               :collect (define-function-macros-with-arity i)))))
(define-function-macros)


;;
;; Functions for building and applying function entries
;;

(defun construct-function-entry (function arity)
  "Construct a FUNCTION-ENTRY object with ARITY

NOTE: There is no FUNCTION-ENTRY for arity 1 and the function will be returned"
  (cond
      ((= 1 arity) function)
      (t
       (let ((function-constructor (gethash arity *function-constructor-functions*)))
         (unless function-constructor
           (error "Unable to construct function of arity ~A" arity))
         `(,function-constructor ,function)))))

(defun apply-function-entry (function &rest args)
  "Apply a function (OR FUNCTION-ENTRY FUNCTION) constructed by coalton"
  (let* ((arity (length args))
         (function-application (gethash arity *function-application-functions*)))
    (unless function-application
      (error "Unable to apply function of arity ~A" arity))
    `(,function-application ,function ,@args)))
