(let ((source-buffer (current-buffer))
      (forms '()))

  (goto-char (point-min))

  (condition-case nil
      (while t
        (push (read source-buffer) forms))
    (end-of-file nil))

  (with-temp-buffer
    (dolist (form (reverse forms))
      (pp form (current-buffer))
      (insert "\n"))

    (write-region
     (point-min)
     (point-max)
     (concat (buffer-file-name source-buffer)
             ".normalized")))

  (kill-emacs 0))
