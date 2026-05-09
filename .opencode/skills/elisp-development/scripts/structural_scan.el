(condition-case err
    (progn
      (goto-char (point-min))

      ;; Forward traversal: scan every sexp from start to end
      (while (< (point) (point-max))
        (forward-sexp 1))

      ;; Backward traversal: verify reverse navigation
      (goto-char (point-max))
      (while (> (point) (point-min))
        (backward-sexp 1))

      (message "Structural traversal successful")
      (kill-emacs 0))

  (error
   (message "Structural traversal failed: %s" err)
   (kill-emacs 1)))
