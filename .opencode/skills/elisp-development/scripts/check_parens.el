;; -*- lexical-binding: t -*-
;; check_parens.el - Check parentheses balance with line numbers

(defvar ejn-check-parens-file nil
  "File to check for balanced parentheses.")

(defun ejn-check-parens (file)
  "Check parentheses/brackets balance in FILE, report line of first problem."
  (find-file file)
  (let ((final (parse-partial-sexp (point-min) (point-max))))
    (let ((depth (car final)))
      (when (/= depth 0)
        (let ((pos (if (> depth 0) (nth 1 final) nil))
              (stop (nth 5 final)))
          (unless pos
            (when (and stop (> stop 0))
              (setq pos stop)))
          (unless pos
            (setq pos (point-max)))
          (princ (format "Unbalanced parentheses at line %d (depth: %d)\n"
                         (line-number-at-pos pos)
                         depth))
          (kill-emacs 1))))))

(when ejn-check-parens-file
  (ejn-check-parens ejn-check-parens-file))
