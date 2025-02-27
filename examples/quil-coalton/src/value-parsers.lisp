(cl:in-package #:quil-coalton)

(coalton-toplevel
  ;;
  ;; Define some basic value parsers
  ;;

  (declare eof (Parser Unit))
  (define eof
    (Parser
     (fn (str)
       (match (next-char str)
         ((Some (Tuple read-char _)) (Err (ParseError (lisp String (read-char)
                                                   (cl:format cl:nil "Unexpected character '~A' expected EOF" read-char)))))
         ((None) (Ok (Tuple Unit str)))))))

  (declare take (Parser Char))
  (define take
    (Parser
     (fn (str)
       (match (next-char str)
         ((Some t_)
          (Ok t_))
         ((None) (Err parse-error-eof))))))

  (declare char (Char -> (Parser Char)))
  (define (char c)
    (Parser
     (fn (str)
       (match (next-char str)
         ((Some t_)
          (let ((read-char (fst t_)))
            (if (== c read-char)
                (Ok t_)
                (Err (ParseError (lisp String (read-char c) (cl:format cl:nil "Unexpected character '~A' expected '~A'" read-char c)))))))
         ((None) (Err parse-error-eof))))))

  (declare not-char (Char -> (Parser Char)))
  (define (not-char c)
    (Parser
     (fn (str)
       (match (next-char str)
         ((Some t_)
          (let ((read-char (fst t_)))
            (if (== c read-char)
                (Err (ParseError (lisp String (read-char c) (cl:format cl:nil "Unexpected character '~A' expected not '~A'" read-char c))))
                (Ok t_))))
         ((None) (Err parse-error-eof))))))

  (declare parse-string (StringView -> (Parser StringView)))
  (define (parse-string str)
    (let ((f (fn (s)
               (match (next-char s)
                 ((Some (Tuple c s))
                  (>>= (char c) (fn (_) (f s))))
                 ((None) (const-value str))))))
      (f str)))

  (declare whitespace (Parser Unit))
  (define whitespace
    (map (fn (_) Unit)
         (alt (char #\Space)
              (char #\Return))))

  (declare digit (Parser Char))
  (define digit
    (map-error
     (fn (_) (ParseError "Invalid digit"))
     (verify
      (fn (x) (and (>= x #\0)
                   (<= x #\9)))
      take)))

  (declare lowercase (Parser Char))
  (define lowercase
    (map-error
     (fn (_) (ParseError "Invalid lowercase character"))
     (verify
      (fn (x) (and (>= x #\a)
                   (<= x #\z)))
      take)))

  (declare uppercase (Parser Char))
  (define uppercase
    (map-error
     (fn (_) (ParseError "Invalid uppercase character"))
     (verify
      (fn (x) (and (>= x #\A)
                   (<= x #\Z)))
      take)))

  (declare alpha (Parser Char))
  (define alpha (alt lowercase uppercase))

  (declare alphanumeric (Parser Char))
  (define alphanumeric (alt alpha digit))

  (declare natural (Parser Integer))
  (define natural
    (with-context "While parsing natural number"
      (>>= (map parse-int (map into (many1 digit)))
           (fn (i)
             (match i
               ((Some a) (const-value a))
               ((None) (fail "Invalid integer"))))))))
