;;; ejn-notebook-tests.el --- ERT tests for ejn-notebook  -*- lexical-binding: t; -*-

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

;; Tests for ejn-notebook: save (P2-T25) and rename (P2-T26).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'eieio)
(require 'json)

(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory
                                (or load-file-name buffer-file-name))))

(require 'ejn-core)
(require 'ejn-notebook)

(ert-deftest ejn-notebook-p2-t26--rename-renames-ipynb-on-disk ()
  "Verify ejn-notebook-rename renames the .ipynb file on disk."
  (let* ((tmp-dir (expand-file-name "ejn-test" temporary-file-directory))
         (old-path (expand-file-name "oldname.ipynb" tmp-dir))
         (new-path (expand-file-name "newname.ipynb" tmp-dir)))
    (make-directory tmp-dir t)
    (unwind-protect
        (progn
          (with-temp-file old-path
            (insert "{}"))
          (let* ((cell0 (make-instance 'ejn-cell
                                       :type 'code
                                       :source "pass"))
                 (nb (make-instance 'ejn-notebook
                                    :path old-path
                                    :cells (list cell0))))
            (ejn-notebook-rename nb new-path)
            (should-not (file-exists-p old-path))
            (should (file-exists-p new-path))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-notebook-p2-t26--rename-updates-path-slot ()
  "Verify ejn-notebook-rename updates the notebook path slot."
  (let* ((tmp-dir (expand-file-name "ejn-test" temporary-file-directory))
         (old-path (expand-file-name "oldname.ipynb" tmp-dir))
         (new-path (expand-file-name "newname.ipynb" tmp-dir)))
    (make-directory tmp-dir t)
    (unwind-protect
        (progn
          (with-temp-file old-path
            (insert "{}"))
          (let* ((cell0 (make-instance 'ejn-cell
                                       :type 'code
                                       :source "pass"))
                 (nb (make-instance 'ejn-notebook
                                    :path old-path
                                    :cells (list cell0))))
            (ejn-notebook-rename nb new-path)
            (should (string= new-path (slot-value nb 'path)))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-notebook-p2-t26--rename-renames-cache-directory ()
  "Verify cache dir is renamed from old-stem to new-stem."
  (let* ((tmp-dir (expand-file-name "ejn-test" temporary-file-directory))
         (old-path (expand-file-name "oldname.ipynb" tmp-dir))
         (new-path (expand-file-name "newname.ipynb" tmp-dir)))
    (make-directory tmp-dir t)
    (unwind-protect
        (progn
          (with-temp-file old-path
            (insert "{}"))
          (let* ((cell0 (make-instance 'ejn-cell
                                       :type 'code
                                       :source "pass"))
                 (nb (make-instance 'ejn-notebook
                                    :path old-path
                                    :cells (list cell0))))
            (ejn-shadow-write-cell cell0 nb)
            (let ((old-cache (expand-file-name ".ejn-cache/oldname" tmp-dir))
                  (new-cache (expand-file-name ".ejn-cache/newname" tmp-dir)))
              (should (file-directory-p old-cache))
              (ejn-notebook-rename nb new-path)
              (should-not (file-directory-p old-cache))
              (should (file-directory-p new-cache)))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-notebook-p2-t26--rename-returns-t-on-success ()
  "Verify ejn-notebook-rename returns t on success."
  (let* ((tmp-dir (expand-file-name "ejn-test" temporary-file-directory))
         (old-path (expand-file-name "oldname.ipynb" tmp-dir))
         (new-path (expand-file-name "newname.ipynb" tmp-dir)))
    (make-directory tmp-dir t)
    (unwind-protect
        (progn
          (with-temp-file old-path
            (insert "{}"))
          (let* ((cell0 (make-instance 'ejn-cell
                                       :type 'code
                                       :source "pass"))
                 (nb (make-instance 'ejn-notebook
                                    :path old-path
                                    :cells (list cell0)))
                 (result (ejn-notebook-rename nb new-path)))
            (should (eq result t))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-notebook-p2-t26--rename-command-is-interactive ()
  "Verify ejn:notebook-rename-command is an interactive command."
  (should (commandp #'ejn:notebook-rename-command)))

;;; ejn-notebook-tests.el ends here
