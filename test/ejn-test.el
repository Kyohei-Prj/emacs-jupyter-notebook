;;; ejn-test.el --- Tests for EJN  -*- lexical-binding: t -*-

;; Copyright (C) 2025  EJN Contributors

;; Author: EJN Contributors
;; Version: 0.1.0
;; Keywords: jupyter, notebook, emacs

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

;; Test suite for Emacs Jupyter Notebook - scaffolding only.

;;; Code:

;; Stub jupyter functions BEFORE requiring ejn (stub-before-load pattern)
(defvar ejn-test--jupyter-disconnect-calls nil
  "Test variable: captured args for jupyter-disconnect stub.")

(defvar ejn-test--jupyter-connect-calls nil
  "Test variable: captured args for jupyter-connect stub.")

(defun jupyter-disconnect (client)
  "Stub for jupyter-disconnect that captures arguments for testing."
  (push client ejn-test--jupyter-disconnect-calls)
  nil)

(defun jupyter-connect (client)
  "Stub for jupyter-connect that captures arguments for testing."
  (push client ejn-test--jupyter-connect-calls)
  nil)

;; P4-T35: Stub jupyter functions BEFORE requiring ejn
(defvar ejn-test--jupyter-current-server-result nil
  "Test variable: return value for jupyter-current-server stub.")

(defvar ejn-test--jupyter-api-get-kernel-result nil
  "Test variable: return value for jupyter-api-get-kernel stub.")

(defvar ejn-test--jupyter-client-calls nil
  "Test variable: captured args for jupyter-client stub.")

(defvar ejn-test--jupyter-server-kernel-calls nil
  "Test variable: captured args for jupyter-server-kernel stub.")

(defun jupyter-current-server (&optional ask)
  "Stub for jupyter-current-server that returns a configured value."
  ejn-test--jupyter-current-server-result)

(defun jupyter-api-get-kernel (server &optional id)
  "Stub for jupyter-api-get-kernel that returns a configured value."
  ejn-test--jupyter-api-get-kernel-result)

(defun jupyter-client (kernel)
  "Stub for jupyter-client that captures arguments for testing."
  (push kernel ejn-test--jupyter-client-calls)
  (make-instance 'ejn-notebook :path "/tmp/stub-client.ipynb"))

(defvar ejn-test--jupyter-server-kernel-last-server nil
  "Test variable: last server arg to jupyter-server-kernel stub.")

(defvar ejn-test--jupyter-server-kernel-last-id nil
  "Test variable: last id arg to jupyter-server-kernel stub.")

(defun jupyter-server-kernel (&rest args)
  "Stub for jupyter-server-kernel that captures arguments for testing."
  (setq ejn-test--jupyter-server-kernel-last-server
	(plist-get args :server))
  (setq ejn-test--jupyter-server-kernel-last-id
	(plist-get args :id))
  (push (list :server ejn-test--jupyter-server-kernel-last-server
		:id ejn-test--jupyter-server-kernel-last-id)
	  ejn-test--jupyter-server-kernel-calls)
  (list :server ejn-test--jupyter-server-kernel-last-server
	:id ejn-test--jupyter-server-kernel-last-id))

(require 'buttercup)
(require 'ejn)

;; Empty test suite - Phase 1 scaffolding only.

(describe "EJN"
	  (it "loads without error"
	      (expect 't :to-be-truthy)))

(describe "ejn:file-open"
	  (it "is defined as an interactive command alias"
	      (expect (fboundp 'ejn:file-open) :to-be-truthy)
	      (expect (commandp 'ejn:file-open) :to-be-truthy)))

(describe "ejn-mode"
	  (it "is defined as a minor mode with keymap"
	      (expect (fboundp 'ejn-mode) :to-be-truthy)
	      (expect (boundp 'ejn-mode-map) :to-be-truthy)
	      (expect (keymapp ejn-mode-map) :to-be-truthy)
	      (expect (lookup-key ejn-mode-map (kbd "C-c C-n"))
		      :to-equal #'ejn:worksheet-goto-next-input)
	      (expect (lookup-key ejn-mode-map (kbd "C-c C-a"))
		      :to-equal #'ejn:worksheet-insert-cell-above)
	      (expect (lookup-key ejn-mode-map (kbd "C-c C-k"))
		      :to-equal #'ejn:worksheet-kill-cell)
	      (expect (lookup-key ejn-mode-map (kbd "C-c C-w"))
		      :to-equal #'ejn:worksheet-cut-cell)
	      (expect (lookup-key ejn-mode-map (kbd "C-c M-w"))
		      :to-equal #'ejn:worksheet-copy-cell)))

(describe "P2-T32 cut-cell (C-c C-w)"
	  (it "defines ejn:worksheet-cut-cell as an interactive command"
	      (expect (fboundp 'ejn:worksheet-cut-cell) :to-be-truthy)
	      (expect (commandp 'ejn:worksheet-cut-cell) :to-be-truthy)))

(describe "P2-T29 stub commands"
	  (it "defines ignore-based stubs as aliases to ignore"
	      (expect (fboundp 'ejn:pytools-not-move-cell-down-km) :to-be-truthy)
	      (expect (fboundp 'ejn:pytools-not-move-cell-up-km) :to-be-truthy)
	      (expect (symbol-function 'ejn:pytools-not-move-cell-down-km)
		      :to-equal #'ignore)
	      (expect (symbol-function 'ejn:pytools-not-move-cell-up-km)
		      :to-equal #'ignore))

	  (it "defines Phase 4 stubs as interactive commands"
	      (let ((stubs
		     '(ejn:worksheet-execute-cell-and-insert-below
		       ejn:worksheet-execute-cell-and-goto-next
		       ejn:notebook-reconnect-session
		       ejn:notebook-kill-kernel-then-close
		       ejn:worksheet-execute-cell
		       ejn:worksheet-toggle-output
		       ejn:worksheet-clear-output
		       ejn:worksheet-clear-all-output
		       ejn:worksheet-toggle-cell-type
		       ejn:worksheet-change-cell-type
		       ejn:worksheet-set-output-visibility-all
		       ejn:notebook-kernel-interrupt
		       ejn:notebook-close
		       ejn:tb-show
		       ejn:notebook-scratchsheet-open
		       ejn:shared-output-show-code-cell-at-point
		       ejn:notebook-restart-session)))
		(dolist (cmd stubs)
		  (expect (fboundp cmd) :to-be-truthy)
		  (expect (commandp cmd) :to-be-truthy))))

	  (it "signals user-error when Phase 4 stubs are called"
	      (should-error (ejn:worksheet-execute-cell-and-insert-below)
			    :type 'user-error)))

(describe "P4-T33 ejn-kernel-reconnect"
	  (before-each
	   (setq ejn-test--jupyter-disconnect-calls nil)
	   (setq ejn-test--jupyter-connect-calls nil))

	  (it "calls jupyter-disconnect and jupyter-connect on the existing client"
	      (let* ((client (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
		     (notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"
					      :kernel-id client)))
		(ejn-kernel-reconnect notebook)
		(expect (length ejn-test--jupyter-disconnect-calls) :to-equal 1)
		(expect (car ejn-test--jupyter-disconnect-calls) :to-equal client)
		(expect (length ejn-test--jupyter-connect-calls) :to-equal 1)
		(expect (car ejn-test--jupyter-connect-calls) :to-equal client)))

	  (it "returns the client"
	      (let* ((client (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
		     (notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"
					      :kernel-id client)))
		(expect (ejn-kernel-reconnect notebook) :to-equal client)))

	  (it "signals user-error when no kernel is attached"
	      (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
		(should-error (ejn-kernel-reconnect notebook) :type 'user-error))))

(describe "P4-T35 ejn:notebook-open"
	  (before-each
	   (setq ejn-test--jupyter-current-server-result
		 (list :server "http://localhost:8888"))
	   (setq ejn-test--jupyter-api-get-kernel-result
		 '(((id . "kernel-1") (name . "python3") (last_activity . "2025-01-01T00:00:00Z") (execution_state . "idle") (connections . 1))
		   ((id . "kernel-2") (name . "python3") (last_activity . "2025-01-02T00:00:00Z") (execution_state . "busy") (connections . 2))))
	   (setq ejn-test--jupyter-client-calls nil)
	   (setq ejn-test--jupyter-server-kernel-calls nil))

  (it "presents kernel IDs via completing-read and attaches to selected kernel"
      (with-temp-buffer
	(let* ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
	       (master-buf (generate-new-buffer "*ejn-master:test*")))
	  (oset notebook master-buffer master-buf)
	  (set (make-local-variable 'ejn--notebook) notebook)
	  (unwind-protect
	      (cl-letf (((symbol-function 'completing-read)
			 (lambda (&rest args)
			   "kernel-1")))
		(ejn:notebook-open)
		(expect (length ejn-test--jupyter-server-kernel-calls)
			:to-equal 1)
		(expect (length ejn-test--jupyter-client-calls)
			:to-equal 1)
		;; Kernel client stored in notebook's :kernel-id slot
		(expect (slot-value notebook 'kernel-id) :to-be-truthy)
		;; Kernel manager mode activated in master buffer
		(with-current-buffer master-buf
		  (expect (bound-and-true-p ejn-kernel-manager-mode)
			:to-be-truthy)))
	    (kill-buffer master-buf)))))

	  (it "signals user-error when no kernels are available"
	      (with-temp-buffer
		(setq ejn-test--jupyter-api-get-kernel-result nil)
		(should-error (ejn:notebook-open) :type 'user-error)))

	  (it "signals user-error when no server is available"
	      (with-temp-buffer
		(setq ejn-test--jupyter-current-server-result nil)
		(should-error (ejn:notebook-open) :type 'user-error))))

;;; ejn-test.el ends here
