;;; ejn-master-tests.el --- ERT tests for ejn-master (P2-T10)  -*- lexical-binding: t; -*-

;; Copyright (C) 2025  EJN Contributors

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Tests for P2-T10: ejn--create-master-view in lisp/ejn-master.el

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'polymode)

;; Ensure lisp/ is on the load-path
(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory
                                (or load-file-name buffer-file-name))))

(require 'ejn-core)
(require 'ejn-cell)
(require 'ejn-master)
(require 'ejn)

;;; Tests — P2-T10: ejn--create-master-view

(ert-deftest ejn-master-p2-t10--creates-buffer-in-special-mode ()
  "Verify `ejn--create-master-view' creates a buffer. poly-ejn-mode uses special-mode as host, so major-mode is special-mode."
  (let* ((tmpdir (make-temp-file "ejn-test-master-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (buf nil))
    (unwind-protect
        (progn
          (setq buf (ejn--create-master-view nb))
          (should (buffer-live-p buf))
          (with-current-buffer buf
            (should (eq major-mode 'special-mode))))
      (when (and buf (buffer-live-p buf))
        (kill-buffer buf))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t10--sets-buffer-local-notebook ()
  "Verify `ejn--create-master-view' stores NOTEBOOK as buffer-local `ejn--notebook'."
  (let* ((tmpdir (make-temp-file "ejn-test-master-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (buf nil))
    (unwind-protect
        (progn
          (setq buf (ejn--create-master-view nb))
          (with-current-buffer buf
            (should (boundp 'ejn--notebook))
            (should (equal ejn--notebook nb))))
      (when (and buf (buffer-live-p buf))
        (kill-buffer buf))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t10--registers-kill-buffer-hook ()
  "Verify `ejn--create-master-view' registers `ejn--cleanup-master-view' on `kill-buffer-hook'."
  (let* ((tmpdir (make-temp-file "ejn-test-master-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (buf nil))
    (unwind-protect
        (progn
          (setq buf (ejn--create-master-view nb))
          (with-current-buffer buf
            (should (memq #'ejn--cleanup-master-view kill-buffer-hook))))
      (when (and buf (buffer-live-p buf))
        (kill-buffer buf))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t10--cleanup-function-exists ()
  "Verify `ejn--cleanup-master-view' is a defined function."
  (should (fboundp 'ejn--cleanup-master-view)))

(ert-deftest ejn-master-p2-t10--returns-buffer ()
  "Verify `ejn--create-master-view' returns the created buffer."
  (let* ((tmpdir (make-temp-file "ejn-test-master-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (buf nil))
    (unwind-protect
        (progn
          (setq buf (ejn--create-master-view nb))
          (should (bufferp buf))
          (should (buffer-live-p buf)))
      (when (and buf (buffer-live-p buf))
        (kill-buffer buf))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t10--buffer-name-follows-convention ()
  "Verify the master buffer name follows the `*ejn-master:<name>*' convention."
  (let* ((tmpdir (make-temp-file "ejn-test-master-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (buf nil))
    (unwind-protect
        (progn
          (setq buf (ejn--create-master-view nb))
          (should (string-prefix-p "*ejn-master:" (buffer-name buf)))
          (should (string-suffix-p "*" (buffer-name buf)))
          (should (string-match-p "mynotebook\\.ipynb" (buffer-name buf))))
      (when (and buf (buffer-live-p buf))
        (kill-buffer buf))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t10--render-master-cells-is-function ()
  "Verify `ejn--render-master-cells' is a defined function."
  (should (fboundp 'ejn--render-master-cells)))

;;; Tests — P2-T11: ejn--render-master-cells

(ert-deftest ejn-master-p2-t11--empty-notebook-renders-nothing ()
  "Verify `ejn--render-master-cells' renders nothing for an empty notebook."
  (let* ((tmpdir (make-temp-file "ejn-test-master-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells nil)))
    (unwind-protect
        (with-temp-buffer
          (ejn--render-master-cells nb)
          (should (string= (buffer-substring-no-properties (point-min) (point-max)) "")))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t11--renders-one-button-per-cell ()
  "Verify `ejn--render-master-cells' creates one button per cell."
  (let* ((tmpdir (make-temp-file "ejn-test-master-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell1 (make-instance 'ejn-cell :type 'code :source "x = 1" :exec-count 1))
         (cell2 (make-instance 'ejn-cell :type 'markdown :source "# Hello" :exec-count nil))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell1 cell2))))
    (unwind-protect
        (with-temp-buffer
          (ejn--render-master-cells nb)
          (let ((button-count 0))
            (save-excursion
              (goto-char (point-min))
              (while (search-forward "[code |" nil t)
                (cl-incf button-count)))
            (should (= button-count 1)))
          (let ((button-count 0))
            (save-excursion
              (goto-char (point-min))
              (while (search-forward "[markdown |" nil t)
                (cl-incf button-count)))
            (should (= button-count 1))))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t11--button-text-includes-cell-type ()
  "Verify button text includes the cell type."
  (let* ((tmpdir (make-temp-file "ejn-test-master-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell (make-instance 'ejn-cell :type 'code :source "x = 1" :exec-count 1))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell))))
    (unwind-protect
        (with-temp-buffer
          (ejn--render-master-cells nb)
          (should (string-match-p "code" (buffer-substring-no-properties (point-min) (point-max)))))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t11--button-text-includes-exec-count ()
  "Verify button text includes execution count or (none) if nil."
  (let* ((tmpdir (make-temp-file "ejn-test-master-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell-with-count (make-instance 'ejn-cell :type 'code :source "x = 1" :exec-count 42))
         (cell-without-count (make-instance 'ejn-cell :type 'markdown :source "# Hi" :exec-count nil))
         (nb-with (make-instance 'ejn-notebook
                                 :path nbpath
                                 :cells (list cell-with-count)))
         (nb-without (make-instance 'ejn-notebook
                                    :path nbpath
                                    :cells (list cell-without-count))))
    (unwind-protect
        (progn
          (with-temp-buffer
            (ejn--render-master-cells nb-with)
            (should (string-match-p "In \\[42\\]"
                                    (buffer-substring-no-properties (point-min) (point-max)))))
          (with-temp-buffer
            (ejn--render-master-cells nb-without)
            (should (string-match-p "In \\[(none)\\]"
                                    (buffer-substring-no-properties (point-min) (point-max)))))
          )
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t11--button-text-truncates-long-source ()
  "Verify button text truncates long source previews."
  (let* ((tmpdir (make-temp-file "ejn-test-master-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (long-source (make-string 200 ?x))
         (cell (make-instance 'ejn-cell :type 'code :source long-source :exec-count 1))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell))))
    (unwind-protect
        (with-temp-buffer
          (ejn--render-master-cells nb)
          (let ((content (buffer-substring-no-properties (point-min) (point-max))))
            ;; The source preview portion should be truncated (less than full 200 chars)
            (should (< (length content) 250)))
          ;; But should still contain some of the source
          (should (string-match-p "x" (buffer-substring-no-properties (point-min) (point-max)))))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t11--buttons-separated-by-newlines ()
  "Verify buttons are separated by newline characters."
  (let* ((tmpdir (make-temp-file "ejn-test-master-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell1 (make-instance 'ejn-cell :type 'code :source "a" :exec-count 1))
         (cell2 (make-instance 'ejn-cell :type 'code :source "b" :exec-count 2))
         (cell3 (make-instance 'ejn-cell :type 'code :source "c" :exec-count 3))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell1 cell2 cell3))))
    (unwind-protect
        (with-temp-buffer
          (ejn--render-master-cells nb)
          (let ((content (buffer-substring-no-properties (point-min) (point-max))))
            ;; 3 cells → at least 2 newlines separating them
            (let ((newline-count 0)
                  (i 0))
              (while (< i (length content))
                (when (eq (aref content i) ?\n)
                  (cl-incf newline-count))
                (cl-incf i))
              (should (>= newline-count 2)))))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t11--button-action-opens-cell-buffer ()
  "Verify button action calls `ejn-cell-open-buffer' with the correct cell."
  (require 'button)
  (let* ((tmpdir (make-temp-file "ejn-test-master-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell (make-instance 'ejn-cell :type 'code :source "x = 1" :exec-count 1))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell))))
    (unwind-protect
        (with-temp-buffer
          (ejn--render-master-cells nb)
          ;; Verify buffer has content (button was created)
          (should (> (buffer-size) 0))
          ;; Get the button's action via button-get and call it directly
          ;; (push-button doesn't work in batch mode without display)
          (goto-char (point-min))
          (let ((btn (button-at (point)))
                (action nil))
            (should btn)
            (setq action (button-get btn 'action))
            (should action)
            (funcall action nil))
          ;; After calling the action, the cell's :buffer slot should be set
          (should (slot-value cell 'buffer)))
      (when (and (slot-value cell 'buffer)
                 (buffer-live-p (slot-value cell 'buffer)))
        (kill-buffer (slot-value cell 'buffer))))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

;;; Tests — P2-T12: ejn--refresh-master-cells

(ert-deftest ejn-master-p2-t12--refresh-clears-existing-buttons ()
  "Verify `ejn--refresh-master-cells' clears existing buttons before re-rendering."
  (let* ((tmpdir (make-temp-file "ejn-test-t12-clear-" t))
         (nbpath (expand-file-name "t12-clear.ipynb" tmpdir))
         (cell1 (make-instance 'ejn-cell :type 'code :source "x = 1" :exec-count 1))
         (cell2 (make-instance 'ejn-cell :type 'code :source "y = 2" :exec-count 2))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell1 cell2)))
         (buf nil))
    (unwind-protect
        (progn
          ;; Create the master view with 2 cells
          (setq buf (ejn--create-master-view nb))
          (with-current-buffer buf
            ;; Verify initial state: 2 buttons rendered
            (should (string-match-p "x = 1"
                                    (buffer-substring-no-properties
                                     (point-min) (point-max)))))
          ;; Now remove one cell from the notebook
          (oset nb cells (list cell1))
          ;; Refresh
          (with-current-buffer buf
            (ejn--refresh-master-cells))
          ;; After refresh, only cell1 should remain
          (with-current-buffer buf
            (let ((content (buffer-substring-no-properties
                            (point-min) (point-max))))
              (should (string-match-p "x = 1" content))
              (should-not (string-match-p "y = 2" content)))))
      (when (and buf (buffer-live-p buf))
        (kill-buffer buf))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t12--buffer-not-recreated-after-refresh ()
  "Verify `ejn--refresh-master-cells' does not recreate the buffer."
  (let* ((tmpdir (make-temp-file "ejn-test-t12-buf-" t))
         (nbpath (expand-file-name "t12-buf.ipynb" tmpdir))
         (cell1 (make-instance 'ejn-cell :type 'code :source "a" :exec-count 1))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell1)))
         (buf nil)
         (original-buf-name nil))
    (unwind-protect
        (progn
          (setq buf (ejn--create-master-view nb))
          (setq original-buf-name (buffer-name buf))
          ;; Refresh
          (with-current-buffer buf
            (ejn--refresh-master-cells))
          ;; Buffer should still be live with the same name
          (should (buffer-live-p buf))
          (should (string= (buffer-name buf) original-buf-name)))
      (when (and buf (buffer-live-p buf))
        (kill-buffer buf))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t12--refresh-renders-added-cells ()
  "Verify `ejn--refresh-master-cells' renders newly added cells."
  (let* ((tmpdir (make-temp-file "ejn-test-t12-add-" t))
         (nbpath (expand-file-name "t12-add.ipynb" tmpdir))
         (cell1 (make-instance 'ejn-cell :type 'code :source "a" :exec-count 1))
         (cell2 (make-instance 'ejn-cell :type 'markdown :source "# New" :exec-count nil))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell1)))
         (buf nil))
    (unwind-protect
        (progn
          ;; Create master view with 1 cell
          (setq buf (ejn--create-master-view nb))
          ;; Add a new cell to the notebook
          (oset nb cells (list cell1 cell2))
          ;; Refresh
          (with-current-buffer buf
            (ejn--refresh-master-cells))
          ;; Both cells should now appear
          (with-current-buffer buf
            (let ((content (buffer-substring-no-properties
                            (point-min) (point-max))))
              (should (string-match-p "a" content))
              (should (string-match-p "# New" content)))))
      (when (and buf (buffer-live-p buf))
        (kill-buffer buf))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p2-t12--refresh-with-empty-notebook-clears-buffer ()
  "Verify `ejn--refresh-master-cells' clears the buffer when cells list is empty."
  (let* ((tmpdir (make-temp-file "ejn-test-t12-empty-" t))
         (nbpath (expand-file-name "t12-empty.ipynb" tmpdir))
         (cell1 (make-instance 'ejn-cell :type 'code :source "a" :exec-count 1))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell1)))
         (buf nil))
    (unwind-protect
        (progn
          (setq buf (ejn--create-master-view nb))
          ;; Remove all cells
          (oset nb cells nil)
          ;; Refresh
          (with-current-buffer buf
            (ejn--refresh-master-cells))
          ;; Buffer should be empty
          (with-current-buffer buf
            (should (= (buffer-size) 0))))
      (when (and buf (buffer-live-p buf))
        (kill-buffer buf))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

;;; Tests — P2-T30: ejn-mode enabled in master view buffers

(ert-deftest ejn-master-p2-t30--ejn-mode-enabled-in-master-view ()
  "Verify `ejn-mode' is enabled in the master view buffer after creation."
  (let* ((tmpdir (make-temp-file "ejn-test-t30-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (buf nil))
    (unwind-protect
        (progn
          (setq buf (ejn--create-master-view nb))
          (with-current-buffer buf
            (should ejn-mode)))
      (when (and buf (buffer-live-p buf))
        (kill-buffer buf))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

;;; Tests — P5-T15: poly-ejn-mode polymode definition

(ert-deftest ejn-master-p5-t15--poly-ejn-mode-is-defined ()
  "Verify `poly-ejn-mode' is defined as a function."
  (should (fboundp 'poly-ejn-mode)))

(ert-deftest ejn-master-p5-t15--poly-ejn-hostmode-is-defined ()
  "Verify `poly-ejn-hostmode' hostmode chunkmode is defined."
  (should (boundp 'poly-ejn-hostmode))
  (should (object-of-class-p poly-ejn-hostmode 'pm-host-chunkmode)))

(ert-deftest ejn-master-p5-t15--poly-ejn-code-innermode-is-defined ()
  "Verify `poly-ejn-code-innermode' innermode chunkmode is defined."
  (should (boundp 'poly-ejn-code-innermode))
  (should (object-of-class-p poly-ejn-code-innermode 'pm-inner-chunkmode)))

(ert-deftest ejn-master-p5-t15--poly-ejn-markdown-innermode-is-defined ()
  "Verify `poly-ejn-markdown-innermode' innermode chunkmode is defined."
  (should (boundp 'poly-ejn-markdown-innermode))
  (should (object-of-class-p poly-ejn-markdown-innermode 'pm-inner-chunkmode)))

(ert-deftest ejn-master-p5-t15--host-mode-is-special-mode ()
  "Verify the hostmode uses special-mode."
  (should (eq (oref poly-ejn-hostmode mode) 'special-mode)))

(ert-deftest ejn-master-p5-t15--code-innermode-is-python-mode ()
  "Verify the code innermode uses python-mode."
  (should (eq (oref poly-ejn-code-innermode mode) 'python-mode)))

(ert-deftest ejn-master-p5-t15--markdown-innermode-is-markdown-mode ()
  "Verify the markdown innermode uses markdown-mode."
  (should (eq (oref poly-ejn-markdown-innermode mode) 'markdown-mode)))

(ert-deftest ejn-master-p5-t15--code-head-matcher-matches-sentinel ()
  "Verify code innermode's head-matcher matches sentinel format."
  (let ((matcher (pm-fun-matcher (oref poly-ejn-code-innermode head-matcher))))
    (with-temp-buffer
      (insert "# %%<ejn-cell:0:code>\nsome python code\n# %%<ejn-cell:0:end>\n")
      (goto-char (point-min))
      (let ((span (funcall matcher 1)))
        (should span)
        (should (string-match-p "ejn-cell.*:code"
                                (buffer-substring-no-properties
                                 (car span) (cdr span))))))))

(ert-deftest ejn-master-p5-t15--markdown-head-matcher-matches-sentinel ()
  "Verify markdown innermode's head-matcher matches sentinel format."
  (let ((matcher (pm-fun-matcher (oref poly-ejn-markdown-innermode head-matcher))))
    (with-temp-buffer
      (insert "# %%<ejn-cell:1:markdown>\n# Some markdown\n# %%<ejn-cell:1:end>\n")
      (goto-char (point-min))
      (let ((span (funcall matcher 1)))
        (should span)
        (should (string-match-p "ejn-cell.*:markdown"
                                (buffer-substring-no-properties
                                 (car span) (cdr span))))))))

(ert-deftest ejn-master-p5-t15--tail-matcher-matches-end-sentinel ()
  "Verify both innermodes' tail-matcher matches end sentinel format."
  (dolist (innermode (list poly-ejn-code-innermode poly-ejn-markdown-innermode))
    (let ((matcher (pm-fun-matcher (oref innermode tail-matcher))))
      (with-temp-buffer
        (insert "# %%<ejn-cell:0:end>")
        (goto-char (point-min))
        (let ((span (funcall matcher 1)))
          (should span)
          (should (string-match-p "ejn-cell.*:end"
                                  (buffer-substring-no-properties
                                   (car span) (cdr span)))))))))

(ert-deftest ejn-master-p5-t15--polymode-config-has-correct-innermodes ()
  "Verify poly-ejn-mode's polymode config includes both innermodes."
  (let* ((config poly-ejn-polymode)
         (innermodes (oref config innermodes)))
    (should (memq 'poly-ejn-code-innermode innermodes))
    (should (memq 'poly-ejn-markdown-innermode innermodes))))

;;; Tests — P5-T16: ejn--poly-render-cells

(ert-deftest ejn-master-p5-t16--function-exists ()
  "Verify `ejn--poly-render-cells' is a defined function."
  (should (fboundp 'ejn--poly-render-cells)))

(ert-deftest ejn-master-p5-t16--empty-notebook-renders-nothing ()
  "Verify `ejn--poly-render-cells' renders nothing for an empty notebook."
  (let* ((tmpdir (make-temp-file "ejn-test-poly-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells nil)))
    (unwind-protect
        (with-temp-buffer
          (ejn--poly-render-cells nb)
          (should (= (buffer-size) 0)))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p5-t16--renders-code-cell-with-delimiters ()
  "Verify `ejn--poly-render-cells' renders a code cell with correct polymode delimiters."
  (let* ((tmpdir (make-temp-file "ejn-test-poly-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell (make-instance 'ejn-cell :type 'code :source "x = 1"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell))))
    (unwind-protect
        (with-temp-buffer
          (ejn--poly-render-cells nb)
          (let ((content (buffer-substring-no-properties (point-min) (point-max))))
            (should (string-prefix-p "# %%<ejn-cell:0:code>" content))
            (should (string-suffix-p "# %%<ejn-cell:0:end>\n" content))
            (should (string-match-p "x = 1" content))))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p5-t16--renders-markdown-cell-with-delimiters ()
  "Verify `ejn--poly-render-cells' renders a markdown cell with correct polymode delimiters."
  (let* ((tmpdir (make-temp-file "ejn-test-poly-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell (make-instance 'ejn-cell :type 'markdown :source "# Hello"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell))))
    (unwind-protect
        (with-temp-buffer
          (ejn--poly-render-cells nb)
          (let ((content (buffer-substring-no-properties (point-min) (point-max))))
            (should (string-prefix-p "# %%<ejn-cell:0:markdown>" content))
            (should (string-suffix-p "# %%<ejn-cell:0:end>\n" content))
            (should (string-match-p "# Hello" content))))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p5-t16--cell-content-between-head-and-tail ()
  "Verify cell source appears between the head and tail delimiters."
  (let* ((tmpdir (make-temp-file "ejn-test-poly-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell (make-instance 'ejn-cell :type 'code :source "print('hi')"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell))))
    (unwind-protect
        (with-temp-buffer
          (ejn--poly-render-cells nb)
          (let ((content (buffer-substring-no-properties (point-min) (point-max))))
            (should (string-match "^# %%<ejn-cell:0:code>\nprint('hi')\n# %%<ejn-cell:0:end>\n$"
                                  content))))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p5-t16--multiple-cells-have-correct-indices ()
  "Verify multiple cells are rendered with sequential indices."
  (let* ((tmpdir (make-temp-file "ejn-test-poly-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell0 (make-instance 'ejn-cell :type 'code :source "a = 1"))
         (cell1 (make-instance 'ejn-cell :type 'markdown :source "# B"))
         (cell2 (make-instance 'ejn-cell :type 'code :source "c = 3"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell0 cell1 cell2))))
    (unwind-protect
        (with-temp-buffer
          (ejn--poly-render-cells nb)
          (let ((content (buffer-substring-no-properties (point-min) (point-max))))
            (should (string-match-p "# %%<ejn-cell:0:code>" content))
            (should (string-match-p "# %%<ejn-cell:0:end>" content))
            (should (string-match-p "# %%<ejn-cell:1:markdown>" content))
            (should (string-match-p "# %%<ejn-cell:1:end>" content))
            (should (string-match-p "# %%<ejn-cell:2:code>" content))
            (should (string-match-p "# %%<ejn-cell:2:end>" content))))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-master-p5-t16--mixed-code-and-markdown-cells ()
  "Verify code and markdown cells are rendered with their respective delimiter types."
  (let* ((tmpdir (make-temp-file "ejn-test-poly-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (code-cell (make-instance 'ejn-cell :type 'code :source "foo()"))
         (md-cell (make-instance 'ejn-cell :type 'markdown :source "*bold*"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list code-cell md-cell))))
    (unwind-protect
        (with-temp-buffer
          (ejn--poly-render-cells nb)
          (let ((content (buffer-substring-no-properties (point-min) (point-max))))
            ;; Cell 0 should use :code delimiter
            (should (string-match-p "# %%<ejn-cell:0:code>" content))
            (should-not (string-match-p "# %%<ejn-cell:0:markdown>" content))
            ;; Cell 1 should use :markdown delimiter
            (should (string-match-p "# %%<ejn-cell:1:markdown>" content))
            (should-not (string-match-p "# %%<ejn-cell:1:code>" content))
            ;; Content should be present
            (should (string-match-p "foo()" content))
            (should (string-match-p "\\*bold\\*" content))))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

;;; Tests — P5-T17: ejn--poly-refresh-cells

(ert-deftest ejn-master-p5-t17--clears-and-re-renders-with-poly-delimiters ()
  "Verify `ejn--poly-refresh-cells' clears buffer and re-renders with polymode chunk delimiters."
  (let* ((tmpdir (make-temp-file "ejn-test-p17-" t))
         (nbpath (expand-file-name "t17-refresh.ipynb" tmpdir))
         (cell1 (make-instance 'ejn-cell :type 'code :source "old = 1"))
         (cell2 (make-instance 'ejn-cell :type 'code :source "new = 2"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell1)))
         (buf nil))
    (unwind-protect
        (progn
          ;; Create master view with 1 cell
          (setq buf (ejn--create-master-view nb))
          ;; Replace cells with a new cell
          (oset nb cells (list cell2))
          ;; Call the poly refresh
          (with-current-buffer buf
            (ejn--poly-refresh-cells))
          ;; Buffer should now contain polymode delimiters for the new cell
          (with-current-buffer buf
            (let ((content (buffer-substring-no-properties
                            (point-min) (point-max))))
              ;; Should have polymode delimiters for new cell
              (should (string-match-p "# %%<ejn-cell:0:code>" content))
              (should (string-match-p "# %%<ejn-cell:0:end>" content))
              (should (string-match-p "new = 2" content))
              ;; Should NOT have old cell content
              (should-not (string-match-p "old = 1" content))
              ;; Should NOT have button-style content from old renderer
              (should-not (string-match-p "\\[code |" content)))))
      (when (and buf (buffer-live-p buf))
        (kill-buffer buf))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

;;; Tests — P5-T18: Wire ejn--poly-render-cells into ejn--create-master-view

(ert-deftest ejn-master-p5-t18--master-view-uses-poly-ejn-mode-and-renderer ()
  "Smoke: `ejn--create-master-view' activates poly-ejn-mode and renders with chunk delimiters.
poly-ejn-mode uses special-mode as host, so major-mode reflects special-mode."
  (let* ((tmpdir (make-temp-file "ejn-test-p18-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell1 (make-instance 'ejn-cell :type 'code :source "x = 1"))
         (cell2 (make-instance 'ejn-cell :type 'markdown :source "# Hello"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell1 cell2)))
         (buf nil))
    (unwind-protect
        (progn
          (setq buf (ejn--create-master-view nb))
          (with-current-buffer buf
            ;; Polymode is active (host mode is special-mode)
            (should (eq major-mode 'special-mode))
            ;; Buffer contains polymode chunk delimiters (proves poly renderer was used)
            (let ((content (buffer-substring-no-properties (point-min) (point-max))))
              (should (string-match-p "%%<ejn-cell:0:code>" content))
              (should (string-match-p "%%<ejn-cell:0:end>" content))
              (should (string-match-p "%%<ejn-cell:1:markdown>" content))
              (should (string-match-p "%%<ejn-cell:1:end>" content))
              ;; Cell sources appear between delimiters
              (should (string-match-p "x = 1" content))
              (should (string-match-p "# Hello" content)))))
      (when (and buf (buffer-live-p buf))
        (kill-buffer buf))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

;;; Tests — P2-T1: window-scroll-functions hook is buffer-local

(ert-deftest ejn-master-p2-t1--scroll-hook-is-buffer-local ()
  "Smoke: `ejn--master-scroll-hook' is registered on the master buffer's local
`window-scroll-functions' only, not on the global value."
  (let* ((tmpdir (make-temp-file "ejn-test-p2t1-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (global-before window-scroll-functions)
         (buf nil))
    (unwind-protect
        (progn
          (setq buf (ejn--create-master-view nb))
          ;; 1) Hook appears in the master buffer's local window-scroll-functions
          (with-current-buffer buf
            (should (memq #'ejn--master-scroll-hook window-scroll-functions)))
          ;; 2) Global window-scroll-functions is unchanged
          (should (equal window-scroll-functions global-before)))
      (when (and buf (buffer-live-p buf))
        (kill-buffer buf))
      (delete-file nbpath)
      (delete-directory tmpdir 'recursive))))

(provide 'ejn-master-tests)

;;; ejn-master-tests.el ends here
