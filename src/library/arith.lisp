;;;; arith.lisp
;;;;
;;;; Number types and basic arithmetic.

(cl:in-package #:coalton-library)

(cl:declaim (cl:inline %unsigned->signed))
(cl:defun %unsigned->signed (bits x)
  ;; This is the two's complement conversion of X (interpreted as BITS
  ;; bits) to a signed integer (as a Lisp object).
  (cl:-
   (cl:ldb (cl:byte (cl:1- bits) 0) x)
   (cl:dpb 0 (cl:byte (cl:1- bits) 0) x)))

(cl:defmacro %define-overflow-handler (name bits)
  `(cl:defun ,name (value)
    (cl:typecase value
      ((cl:signed-byte ,bits) value)
      (cl:otherwise
       (cl:cerror "Continue, wrapping around."
                  ,(cl:format cl:nil "Signed value overflowed ~D bits." bits))
       (%unsigned->signed ,bits (cl:mod value ,(cl:expt 2 bits)))))))

(cl:eval-when (:compile-toplevel :load-toplevel)
  (cl:defparameter +fixnum-bits+
    #+sbcl sb-vm:n-fixnum-bits
    #-sbcl (cl:1+ (cl:floor (cl:log cl:most-positive-fixnum 2))))
  (cl:defparameter +unsigned-fixnum-bits+
    (cl:1- +fixnum-bits+)))

(%define-overflow-handler %handle-8bit-overflow 8)
(%define-overflow-handler %handle-16bit-overflow 16)
(%define-overflow-handler %handle-32bit-overflow 32)
(%define-overflow-handler %handle-64bit-overflow 64)
(%define-overflow-handler %handle-fixnum-overflow #.+fixnum-bits+)

(cl:defmacro %define-number-stuff (coalton-type)
  `(coalton-toplevel
     (define-instance (Eq ,coalton-type)
       (define (== a b)
         (lisp Boolean (a b)
           (to-boolean (cl:= a b)))))

     (define-instance (Ord ,coalton-type)
       (define (<=> a b)
         (lisp Ord (a b)
           (cl:cond
             ((cl:< a b)
              LT)
             ((cl:> a b)
              GT)
             (cl:t
              EQ)))))))

(%define-number-stuff U8)
(%define-number-stuff U16)
(%define-number-stuff U32)
(%define-number-stuff U64)
(%define-number-stuff I8)
(%define-number-stuff I16)
(%define-number-stuff I32)
(%define-number-stuff I64)
(%define-number-stuff Integer)
(%define-number-stuff IFix)
(%define-number-stuff UFix)
(%define-number-stuff Single-Float)
(%define-number-stuff Double-Float)


(coalton-toplevel
  (define-instance (Num I8)
    (define (+ a b)
      (lisp I8 (a b)
        (%handle-8bit-overflow (cl:+ a b))))
    (define (- a b)
      (lisp I8 (a b)
        (%handle-8bit-overflow (cl:- a b))))
    (define (* a b)
      (lisp I8 (a b)
        (%handle-8bit-overflow (cl:* a b))))
    (define (fromInt x)
      (lisp I8 (x)
        (%handle-8bit-overflow x))))

  (define-instance (Num I16)
    (define (+ a b)
      (lisp I16 (a b)
        (%handle-16bit-overflow (cl:+ a b))))
    (define (- a b)
      (lisp I16 (a b)
        (%handle-16bit-overflow (cl:- a b))))
    (define (* a b)
      (lisp I16 (a b)
        (%handle-16bit-overflow (cl:* a b))))
    (define (fromInt x)
      (lisp I16 (x)
        (%handle-16bit-overflow x))))

  (define-instance (Num I32)
    (define (+ a b)
      (lisp I32 (a b)
        (%handle-32bit-overflow (cl:+ a b))))
    (define (- a b)
      (lisp I32 (a b)
        (%handle-32bit-overflow (cl:- a b))))
    (define (* a b)
      (lisp I32 (a b)
        (%handle-32bit-overflow (cl:* a b))))
    (define (fromInt x)
      (lisp I32 (x)
        (%handle-32bit-overflow x))))

  (define-instance (Num I64)
    (define (+ a b)
      (lisp I64 (a b)
        (%handle-64bit-overflow (cl:+ a b))))
    (define (- a b)
      (lisp I64 (a b)
        (%handle-64bit-overflow (cl:- a b))))
    (define (* a b)
      (lisp I64 (a b)
        (%handle-64bit-overflow (cl:* a b))))
    (define (fromInt x)
      (lisp I64 (x)
        (%handle-64bit-overflow x))))

  (define-instance (Num IFix)
    (define (+ a b)
      (lisp IFix (a b)
        (%handle-fixnum-overflow (cl:+ a b))))
    (define (- a b)
      (lisp IFix (a b)
        (%handle-fixnum-overflow (cl:- a b))))
    (define (* a b)
      (lisp IFix (a b)
        (%handle-fixnum-overflow (cl:* a b))))
    (define (fromInt x)
      (lisp IFix (x)
        (%handle-fixnum-overflow x)))))


(cl:defmacro %define-signed-instances (coalton-type bits)
  (cl:declare (cl:ignore bits))
  `(coalton-toplevel
     (define-instance (Into Integer ,coalton-type)
       (define (into x) (fromInt x)))

     (define-instance (Into ,coalton-type Integer)
       (define (into x)
         (lisp Integer (x)
           x)))))

(%define-signed-instances I8  8)
(%define-signed-instances I16 16)
(%define-signed-instances I32 32)
(%define-signed-instances I64 64)
(%define-signed-instances IFix #.+fixnum-bits+)


(cl:defmacro %define-unsigned-num-instance (coalton-type bits)
  `(coalton-toplevel
     (define-instance (Num ,coalton-type)
       (define (+ a b)
         (lisp ,coalton-type (a b)
           (cl:values (cl:mod (cl:+ a b) ,(cl:expt 2 bits)))))
       (define (- a b)
         (lisp ,coalton-type (a b)
           (cl:values (cl:mod (cl:- a b) ,(cl:expt 2 bits)))))
       (define (* a b)
         (lisp ,coalton-type (a b)
           (cl:values (cl:mod (cl:* a b) ,(cl:expt 2 bits)))))
       (define (fromInt x)
         (lisp ,coalton-type (x)
           (cl:values (cl:mod x ,(cl:expt 2 bits))))))

     (define-instance (Into Integer ,coalton-type)
       (define (into x) (fromInt x)))

     (define-instance (Into ,coalton-type Integer)
       (define (into x)
         (lisp Integer (x)
           x)))

     (define-instance (Into ,coalton-type Single-Float)
       (define (into x)
         (lisp Single-Float (x)
           (cl:coerce x 'cl:single-float))))

     (define-instance (Into ,coalton-type Double-Float)
       (define (into x)
         (lisp Double-Float (x)
           (cl:coerce x 'cl:double-float))))))

(%define-unsigned-num-instance U8  8)
(%define-unsigned-num-instance U16 16)
(%define-unsigned-num-instance U32 32)
(%define-unsigned-num-instance U64 64)
(%define-unsigned-num-instance UFix #.+unsigned-fixnum-bits+)

(coalton-toplevel
  (declare integer->single-float (Integer -> Single-Float))
  (define (integer->single-float z)
    (lisp Single-Float (z)
      (cl:let ((x (cl:ignore-errors
                   (cl:coerce z 'cl:single-float))))
        (cl:if (cl:null x)
               float-features:single-float-nan
               x))))

  (declare integer->double-float (Integer -> Double-Float))
  (define (integer->double-float z)
    (lisp Double-Float (z)
      (cl:let ((x (cl:ignore-errors
                   (cl:coerce z 'cl:double-float))))
        (cl:if (cl:null x)
               float-features:double-float-nan
               x))))

  (declare single-float->integer (Single-Float -> (Optional Integer)))
  (define (single-float->integer x)
    "Round a Single-Float to the nearest Integer."
    (lisp (Optional Integer) (x)
      (cl:if (cl:or (float-features:float-infinity-p x)
                    (float-features:float-nan-p x))
             None
             (Some (cl:round x)))))

  (declare double-float->integer (Double-Float -> (Optional Integer)))
  (define (double-float->integer x)
    "Round a Double-Float to the nearest Integer."
    (lisp (Optional Integer) (x)
      (cl:if (cl:or (float-features:float-infinity-p x)
                    (float-features:float-nan-p x))
             None
             (Some (cl:round x))))))

(coalton-toplevel
  (define-instance (Eq Fraction)
    (define (== p q)
      (and (== (numerator p) (numerator q))
           (== (denominator p) (denominator q)))))

  (define-instance (Ord Fraction)
    (define (<=> p q)
      (<=> (* (numerator p) (denominator q))
           (* (numerator q) (denominator p)))))

  (define-instance (Num Integer)
    (define (+ a b)
      (lisp Integer (a b) (cl:+ a b)))
    (define (- a b)
      (lisp Integer (a b) (cl:- a b)))
    (define (* a b)
      (lisp Integer (a b) (cl:* a b)))
    (define (fromInt x)
      x))

  (define-instance (Num Single-Float)
    (define (+ a b)
      (lisp Single-Float (a b) (cl:+ a b)))
    (define (- a b)
      (lisp Single-Float (a b) (cl:- a b)))
    (define (* a b)
      (lisp Single-Float (a b) (cl:* a b)))
    (define (fromInt x)
      (integer->single-float x)))

  (define-instance (Num Double-Float)
    (define (+ a b)
      (lisp Double-Float (a b) (cl:+ a b)))
    (define (- a b)
      (lisp Double-Float (a b) (cl:- a b)))
    (define (* a b)
      (lisp Double-Float (a b) (cl:* a b)))
    (define (fromInt x)
      (integer->double-float x)))

  (declare negate ((Num :a) => (:a -> :a)))
  (define (negate x)
    (- (fromInt 0) x))

  (declare abs ((Ord :a) (Num :a) => (:a -> :a)))
  (define (abs x)
    "Absolute value of X."
    (if (< x (fromInt 0))
        (negate x)
        x))

  (declare sign ((Ord :a) (Num :a) => (:a -> Integer)))
  (define (sign x)
    "The sign of X."
    (if (< x (fromInt 0))
        -1
        1))

  (declare expt (Integer -> Integer -> Integer))
  (define (expt base power)
    "Exponentiate BASE to a non-negative POWER."
    (if (< power 0)
        (error "Can't exponentiate with a negative exponent.")
        (lisp Integer (base power) (cl:expt base power))))

  (declare ash (Integer -> Integer -> Integer))
  (define (ash x n)
    "Compute the \"arithmetic shift\" of X by N. "
    (lisp Integer (x n) (cl:ash x n)))

  (declare mod (Integer -> Integer -> Integer))
  (define (mod num base)
    "Compute NUM modulo BASE."
    (if (== base 0)
        (error "Can't mod by 0.")
        (lisp Integer (num base) (cl:values (cl:mod num base)))))

  (declare even (Integer ->  Boolean))
  (define (even n)
    "Is N even?"
    (lisp Boolean (n) (to-boolean (cl:evenp n))))

  (declare odd (Integer -> Boolean))
  (define (odd n)
    "Is N odd?"
    (lisp Boolean (n) (to-boolean (cl:oddp n))))

  (declare gcd (Integer -> Integer -> Integer))
  (define (gcd a b)
    "Compute the greatest common divisor of A and B."
    (lisp Integer (a b) (cl:gcd a b)))

  (declare lcm (Integer -> Integer -> Integer))
  (define (lcm a b)
    "Compute the least common multiple of A and B."
    (lisp Integer (a b) (cl:lcm a b)))

  (declare %reduce-fraction (Fraction -> Fraction))
  (define (%reduce-fraction q)
    (let ((n (numerator q))
          (d (denominator q))
          (g (gcd n d)))
      (if (== 0 n)
          (%Fraction 0 1)
          (%Fraction
           (* (* (sign n) (sign d))
              (lisp Integer (n g) (cl:values (cl:floor n g))))
           (lisp Integer (d g) (cl:values (cl:floor (cl:abs d) g)))))))

  (define (%mkFraction n d)
    (progn
      (when (== 0 d)
        (error "Division by zero"))
      (%reduce-fraction
       (%Fraction n d))))

  (declare numerator (Fraction -> Integer))
  (define (numerator q)
    "The numerator of a fraction."
    (match q
      ((%Fraction n _) n)))

  (declare denominator (Fraction -> Integer))
  (define (denominator q)
    "The denominator of a fraction."
    (match q
      ((%Fraction _ d) d)))

  (declare reciprocal (Fraction -> Fraction))
  (define (reciprocal q)
    "The reciprocal of a fraction."
    (match q
      ;; n/d and d/n will always be reduced
      ((%Fraction n d) (%Fraction d n))))

  (define-instance (Num Fraction)
    (define (+ p q)
      (let ((a (* (numerator p) (denominator q)))
            (b (* (numerator q) (denominator p)))
            (c (* (denominator p) (denominator q))))
        (%mkFraction (+ a b) c)))
    (define (- p q)
      (let ((a (* (numerator p) (denominator q)))
            (b (* (numerator q) (denominator p)))
            (c (* (denominator p) (denominator q))))
        (%mkFraction (- a b) c)))
    (define (* p q)
      (%mkFraction (* (numerator p) (numerator q))
                   (* (denominator p) (denominator q))))
    (define (fromInt z)
      (%Fraction z 1)))

  (define-instance (Dividable Fraction Fraction)
    (define (/ a b)
      (* a (reciprocal b))))

  (define-instance (Dividable Single-Float Single-Float)
    (define (/ x y)
      (lisp Single-Float (x y)
        (cl:/ x y))))

  (define-instance (Dividable Double-Float Double-Float)
    (define (/ x y)
      (lisp Double-Float (x y)
        (cl:/ x y))))

  (define-instance (Dividable Integer Fraction)
    (define (/ x y)
      (%mkFraction x y)))

  (define-instance (Dividable Integer Single-Float)
    (define (/ x y)
      (lisp Single-Float (x y)
        (cl:coerce (cl:/ x y) 'cl:single-float))))

  (define-instance (Dividable Integer Double-Float)
    (define (/ x y)
      (lisp Double-Float (x y)
        (cl:coerce (cl:/ x y) 'cl:double-float))))
  )

(coalton-toplevel
  (define-type (Complex :a)
    "Represents a complex algebra of a given type."
    (Complex :a :a))

  (declare real-part ((Complex :a) -> :a))
  (define (real-part z)
    "The real part of a complex number."
    (match z
      ((Complex a _) a)))

  (declare imag-part ((Complex :a) -> :a))
  (define (imag-part z)
    "The imaginary part of a complex number."
    (match z
      ((Complex _ b) b)))

  (define-instance ((Eq :a) => (Eq (Complex :a)))
    (define (== p q)
      (and (== (real-part p) (real-part q))
           (== (imag-part p) (imag-part q)))))

  (define-instance ((Num :a) => (Num (Complex :a)))
    (define (+ a b)
      (Complex (+ (real-part a) (real-part b))
               (+ (imag-part a) (imag-part b))))
    (define (- a b)
      (Complex (+ (real-part a) (real-part b))
               (+ (imag-part a) (imag-part b))))
    (define (* a b)
      (match (Tuple a b)
        ((Tuple (Complex ra ia)
                (Complex rb ib))
         (Complex (- (* ra rb) (* ia ib))
                  (+ (* ra ib) (* ia rb))))))
    (define (fromInt x)
      (Complex (fromInt x) (fromInt 0))))

  (declare conjugate ((Num :a) => (Complex :a) -> (Complex :a)))
  (define (conjugate z)
    (Complex (real-part z) (negate (imag-part z))))

  (declare ii ((Num :a) => (Complex :a)))
  (define ii
    "The complex unit i. (The double ii represents a blackboard-bold i.)"
    (Complex (fromInt 0) (fromInt 1)))

  (define-instance ((Num :a) (Dividable :a :a) => (Dividable (Complex :a) (Complex :a)))
    (define (/ a b)
      (match (Tuple a b)
        ((Tuple (Complex ra ia)
                (Complex rb ib))
         (let ((d (+ (* rb rb) (* ib ib))))
           (Complex (/ (+ (* ia ib) (* ra rb)) d)
                    (/ (- (* ia rb) (* ra ib)) d))))))))

(coalton-toplevel
  (define-instance (Into Integer String)
    (define (into z)
      (lisp String (z)
        (cl:format cl:nil "~D" z))))

  (define-instance (TryInto String Integer)
    (define (tryInto s)
      (lisp (Result String Integer) (s)
        (cl:let ((z (cl:ignore-errors (cl:parse-integer s))))
          (cl:if (cl:null z)
                 (Err "String doesn't have integer syntax.")
                 (Ok z))))))

  (define-instance ((Num :a) => (Into :a (Complex :a)))
    (define (into x)
      (Complex x (fromInt 0)))))

;;;; `Bits' instances
;;; signed

(cl:defmacro define-signed-bit-instance (type handle-overflow)
  (cl:flet ((lisp-binop (op)
              `(lisp ,type (left right)
                     (,op left right))))
    `(coalton-toplevel
       (define-instance (Bits ,type)
         (define (bit-and left right)
           ,(lisp-binop 'cl:logand))
         (define (bit-or left right)
           ,(lisp-binop 'cl:logior))
         (define (bit-xor left right)
           ,(lisp-binop 'cl:logxor))
         (define (bit-not bits)
           (lisp ,type (bits) (cl:lognot bits)))
         (define (bit-shift amount bits)
           (lisp ,type (amount bits)
             (,handle-overflow (cl:ash bits amount))))))))

(define-signed-bit-instance I8 %handle-8bit-overflow)
(define-signed-bit-instance I16 %handle-16bit-overflow)
(define-signed-bit-instance I32 %handle-32bit-overflow)
(define-signed-bit-instance I64 %handle-64bit-overflow)
(define-signed-bit-instance IFix %handle-fixnum-overflow)
(define-signed-bit-instance Integer cl:identity)

;;; unsigned

(cl:declaim (cl:inline unsigned-lognot)
            (cl:ftype (cl:function (cl:unsigned-byte cl:unsigned-byte)
                                   (cl:values cl:unsigned-byte cl:&optional))
                      unsigned-lognot))
(cl:defun unsigned-lognot (int n-bits)
  (cl:- (cl:ash 1 n-bits) int 1))
(cl:defmacro define-unsigned-bit-instance (type width)
  (cl:flet ((define-binop (coalton-name lisp-name)
              `(define (,coalton-name left right)
                   (lisp ,type (left right)
                         (,lisp-name left right)))))
    `(coalton-toplevel
      (define-instance (Bits ,type)
        ,(define-binop 'bit-and 'cl:logand)
        ,(define-binop 'bit-or 'cl:logior)
        ,(define-binop 'bit-xor 'cl:logxor)
        (define (bit-not bits)
            (lisp ,type (bits) (unsigned-lognot bits ,width)))
        (define (bit-shift amount bits)
            (lisp ,type (amount bits)
                  (cl:logand (cl:ash bits amount)
                             (cl:1- (cl:ash 1 ,width)))))))))

(define-unsigned-bit-instance U8 8)
(define-unsigned-bit-instance U16 16)
(define-unsigned-bit-instance U32 32)
(define-unsigned-bit-instance U64 64)
(define-unsigned-bit-instance UFix #.+unsigned-fixnum-bits+)

;;;; `Hash' instances

(define-sxhash-hasher I8)
(define-sxhash-hasher I16)
(define-sxhash-hasher I32)
(define-sxhash-hasher I64)
(define-sxhash-hasher U8)
(define-sxhash-hasher U16)
(define-sxhash-hasher U32)
(define-sxhash-hasher U64)
(define-sxhash-hasher Integer)
(define-sxhash-hasher IFix)
(define-sxhash-hasher UFix)
(define-sxhash-hasher Single-Float)
(define-sxhash-hasher Double-Float)


;;; `Quantization'

(coalton-toplevel
  (define-instance (Quantizable Integer)
    (define (quantize x)
      (Quantization x x 0 x 0))))

(cl:macrolet ((define-integer-quantizations (cl:&rest int-types)
                `(coalton-toplevel
                   ,@(cl:loop :for ty :in int-types :collect
                        `(define-instance (Quantizable ,ty)
                           (define (quantize x)
                             (let ((n (into x)))
                               (Quantization x n (fromInt 0) n (fromInt 0)))))))))
  (define-integer-quantizations I32 I64 U8 U32 U64))

(coalton-toplevel
  (define-instance (Quantizable Single-Float)
    (define (quantize f)
      (lisp (Quantization Single-Float) (f)
        (uiop:nest
         (cl:multiple-value-bind (fl-quo fl-rem) (cl:floor f))
         (cl:multiple-value-bind (ce-quo ce-rem) (cl:ceiling f))
         (Quantization f fl-quo fl-rem ce-quo ce-rem)))))

  (define-instance (Quantizable Double-Float)
    (define (quantize f)
      (lisp (Quantization Double-Float) (f)
        (uiop:nest
         (cl:multiple-value-bind (fl-quo fl-rem) (cl:floor f))
         (cl:multiple-value-bind (ce-quo ce-rem) (cl:ceiling f))
         (Quantization f fl-quo fl-rem ce-quo ce-rem)))))

  (define-instance (Quantizable Fraction)
    (define (quantize q)
      (let ((n (numerator q))
            (d (denominator q)))
        (lisp (Quantization Fraction) (n d)
          ;; Not the most efficient... just relying on CL to do the
          ;; work.
          (cl:flet ((to-frac (f)
                      (%Fraction (cl:numerator f) (cl:denominator f))))
            (cl:let ((f (cl:/ n d)))
              (uiop:nest
               (cl:multiple-value-bind (fl-quo fl-rem) (cl:floor f))
               (cl:multiple-value-bind (ce-quo ce-rem) (cl:ceiling f))
               (Quantization f
                             fl-quo (to-frac fl-rem)
                             ce-quo (to-frac ce-rem)))))))))

  (define (floor x)
    "Return the greatest integer less than or equal to X."
    (match (quantize x)
      ((Quantization _ z _ _ _) z)))

  (define (ceiling x)
    "Return the least integer greater than or equal to X."
    (match (quantize x)
      ((Quantization _ _ _ z _) z)))

  (define (round x)
    "Return the nearest integer to X, with ties breaking toward positive infinity."
    (match (quantize x)
      ((Quantization _ a ar b br)
       (match (<=> (abs ar) (abs br))
         ((LT) a)
         ((GT) b)
         ((EQ) (max a b))))))

  (declare safe/ ((Dividable :a :b) => (:a -> :a -> (Optional :b))))
  (define (safe/ x y)
    "Safely divide X by Y, returning None if Y is zero."
    (if (== y (fromInt 0))
        None
        (Some (/ x y))))

  (declare exact/ (Integer -> Integer -> Fraction))
  (define (exact/ a b)
    "Exactly divide two integers and produce a fraction."
    (/ a b))

  (declare inexact/ (Integer -> Integer -> Double-Float))
  (define (inexact/ a b)
    "Compute the quotient of integers as a double-precision float.

Note: This does *not* divide double-float arguments."
    (/ a b))

  (declare floor/ (Integer -> Integer -> Integer))
  (define (floor/ a b)
    "Divide two integers and compute the floor of the quotient."
    (floor (exact/ a b)))

  (declare ceiling/ (Integer -> Integer -> Integer))
  (define (ceiling/ a b)
    "Divide two integers and compute the ceiling of the quotient."
    (ceiling (exact/ a b)))

  (declare round/ (Integer -> Integer -> Integer))
  (define (round/ a b)
    "Divide two integers and round the quotient."
    (round (exact/ a b)))

  (declare single/ (Single-Float -> Single-Float -> Single-Float))
  (define (single/ a b)
    "Compute the quotient of single-precision floats as a single-precision float."
    (/ a b))

  (declare double/ (Double-Float -> Double-Float -> Double-Float))
  (define (double/ a b)
    "Compute the quotient of single-precision floats as a single-precision float."
    (/ a b)))

