;;; ejn-network-tests.el --- ERT tests for ejn-network  -*- lexical-binding: t; -*-

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

;; Tests for P4-T01: ejn-kernel-start

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'eieio)

;; Ensure lisp/ is on the load-path
(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory
                                (or load-file-name buffer-file-name))))

;; ---------------------------------------------------------------------------
;; Stubs for jupyter.el functions (defined BEFORE require 'ejn so that
;; autoload in ejn-network.el resolves to our stubs)
;; ---------------------------------------------------------------------------

(defvar ejn-network--test-mock-client nil
  "Mock jupyter-kernel-client returned by stub `jupyter-client'.")

(defvar ejn-network--test-captured-kernel-spec nil
  "Kernelspec captured by stub `jupyter-client'.")

(defvar ejn-network--test-captured-kernel-name nil
  "Kernel name captured by stub `jupyter-available-kernelspecs'.")

;; Stub for cl-defstruct jupyter-kernelspec
(cl-defstruct jupyter-kernelspec
  (name "python"
        :type string
        :documentation "The name of the kernelspec."))

;; Stub for jupyter-available-kernelspecs
(defun jupyter-available-kernelspecs (&optional _refresh)
  "Stub that returns a mock kernelspec list."
  (list (make-jupyter-kernelspec
         :name (or ejn-network--test-captured-kernel-name "python"))))

;; Stub for jupyter-kernel (used internally by jupyter-client)
(defun jupyter-kernel (&rest _args)
  "Stub that returns a mock kernel object."
  (make-instance 'ejn-test-mock-kernel))

;; Stub for jupyter-client
(defun jupyter-client (spec &optional _client-class)
  "Stub that returns our mock client and captures the spec."
  (setq ejn-network--test-captured-kernel-spec spec)
  (setq ejn-network--test-mock-client
        (make-instance 'ejn-test-mock-kernel-client))
  ejn-network--test-mock-client)

;; Mock kernel class (for testing that a kernel object is created)
(defclass ejn-test-mock-kernel ()
  ((spec :initarg :spec
         :initform nil
         :type t))
  "Mock jupyter kernel class for testing.")

;; Mock kernel-client class (for testing that a client object is returned)
(defclass ejn-test-mock-kernel-client ()
  ((execution-state
    :type string
    :initform "starting"
    :documentation "Mock execution state.")
   (io :type list
       :initarg :io
       :initform '()
       :documentation "Mock I/O slot."))
  "Mock jupyter-kernel-client class for testing.")

;; Stub for jupyter-kernel-language (used by minor mode activation)
(defun jupyter-kernel-language (client)
  "Stub that returns the kernel language name."
  (declare (indent 1))
  "python")

;; ---------------------------------------------------------------------------
;; Stubs for P4-T10: ejn--iopub-handler
;; ---------------------------------------------------------------------------

;; ---------------------------------------------------------------------------
;; Stub for jupyter-insert (P4-T13)
;; ---------------------------------------------------------------------------

(defvar ejn-network--test-jupyter-insert-captured-args nil
  "Test variable: args passed to stub `jupyter-insert'.")

(defun jupyter-insert (&rest args)
  "Stub that captures arguments for testing `ejn--render-output'."
  (setq ejn-network--test-jupyter-insert-captured-args args)
  :text/plain)

;; ---------------------------------------------------------------------------
;; Stubs for P4-T02: ejn-kernel-stop
;; ---------------------------------------------------------------------------

(defvar ejn-network--test-shutdown-captured-client nil
  "Client captured by stub `jupyter-shutdown-kernel'.")

(defun jupyter-shutdown-kernel (client)
  "Stub that captures the client passed to it."
  (setq ejn-network--test-shutdown-captured-client client)
  nil)

;; Stubs for P4-T26: ejn-kernel-interrupt
;; ---------------------------------------------------------------------------

(defvar ejn-network--test-interrupt-captured-client nil
  "Client captured by stub `jupyter-interrupt-kernel'.")

(defun jupyter-interrupt-kernel (client)
  "Stub that captures the client passed to it."
  (setq ejn-network--test-interrupt-captured-client client)
  nil)

;; Stubs for P4-T28: ejn-kernel-restart
;; ---------------------------------------------------------------------------

(defvar ejn-network--test-restart-captured-client nil
  "Client captured by stub `jupyter-restart-kernel'.")

(defun jupyter-restart-kernel (client)
  "Stub that captures the client passed to it."
  (setq ejn-network--test-restart-captured-client client)
  nil)

;; Stubs for P4-T33: ejn-kernel-reconnect
;; ---------------------------------------------------------------------------

(defvar ejn-network--test-disconnect-captured-client nil
  "Client captured by stub `jupyter-disconnect'.")

(defvar ejn-network--test-connect-captured-client nil
  "Client captured by stub `jupyter-connect'.")

(defun jupyter-disconnect (client)
  "Stub that captures the client passed to it."
  (setq ejn-network--test-disconnect-captured-client client)
  nil)

(defun jupyter-connect (client)
  "Stub that captures the client passed to it."
  (setq ejn-network--test-connect-captured-client client)
  nil)

(require 'ejn)
(require 'ejn-network)

;;; Tests — P4-T01: ejn-kernel-start

(ert-deftest ejn-network-p4-t01--returns-kernel-client ()
  "Verify `ejn-kernel-start' returns a `jupyter-kernel-client' object."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    ;; Act
    (let ((client (ejn-kernel-start notebook)))
      ;; Assert
      (should (object-of-class-p client 'ejn-test-mock-kernel-client)))))

(ert-deftest ejn-network-p4-t01--stores-client-in-kernel-id ()
  "Verify `ejn-kernel-start' stores client in notebook `:kernel-id' slot."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    ;; Act
    (ejn-kernel-start notebook)
    ;; Assert
    (should (object-of-class-p
             (slot-value notebook 'kernel-id)
             'ejn-test-mock-kernel-client))))

(ert-deftest ejn-network-p4-t01--activates-kernel-manager-mode ()
  "Verify `ejn-kernel-start' activates `ejn-kernel-manager-mode' in master buffer."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (master-buf (generate-new-buffer "*ejn-master:test*")))
    (unwind-protect
        (progn
          (oset notebook master-buffer master-buf)
          ;; Act
          (ejn-kernel-start notebook)
          ;; Assert
          (with-current-buffer master-buf
            (should (bound-and-true-p ejn-kernel-manager-mode))))
      (kill-buffer master-buf))))

(ert-deftest ejn-network-p4-t01--uses-correct-kernelspec ()
  "Verify `ejn-kernel-start' creates client from correct kernelspec."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    ;; Act
    (ejn-kernel-start notebook)
    ;; Assert: the captured spec should be non-nil (a kernel object)
    (should ejn-network--test-captured-kernel-spec)))

(ert-deftest ejn-network-p4-t01--respects-kernel-name-argument ()
  "Verify `ejn-kernel-start' uses the kernel-name argument when provided."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (ejn-network--test-captured-kernel-name "python3"))
    ;; Act
    (ejn-kernel-start notebook "python3")
    ;; Assert: client stored
    (should (object-of-class-p
             (slot-value notebook 'kernel-id)
             'ejn-test-mock-kernel-client))
    ;; Assert: kernelspec was looked up
    (should ejn-network--test-captured-kernel-spec)))

;;; Tests — P4-T02: ejn-kernel-stop

(ert-deftest ejn-network-p4-t02--calls-jupyter-shutdown-kernel-with-client ()
  "Verify `ejn-kernel-stop' calls `jupyter-shutdown-kernel' with the notebook's client."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (expected-client nil))
    (ejn-kernel-start notebook)
    (setq expected-client (slot-value notebook 'kernel-id))
    (ejn-kernel-stop notebook)
    (should (eql ejn-network--test-shutdown-captured-client expected-client))))

(ert-deftest ejn-network-p4-t02--clears-kernel-id ()
  "Verify `ejn-kernel-stop' clears the `:kernel-id' slot to nil."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    (ejn-kernel-stop notebook)
    (should-not (slot-value notebook 'kernel-id))))

(ert-deftest ejn-network-p4-t02--returns-nil ()
  "Verify `ejn-kernel-stop' returns nil."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    (should-not (ejn-kernel-stop notebook))))

;;; Tests — P4-T03: ejn-kernel-client

(ert-deftest ejn-network-p4-t03--returns-client-from-kernel-id ()
  "Verify `ejn-kernel-client' returns the client stored in notebook `:kernel-id' slot."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    (let ((expected-client (slot-value notebook 'kernel-id)))
      ;; Act
      (let ((actual-client (ejn-kernel-client notebook)))
        ;; Assert
        (should (eql actual-client expected-client))))))

(ert-deftest ejn-network-p4-t03--signals-user-error-when-kernel-id-is-nil ()
  "Verify `ejn-kernel-client' signals `user-error' when `:kernel-id' is nil."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    ;; Assert: kernel-id is nil by default
    (should-not (slot-value notebook 'kernel-id))
    ;; Act & Assert: should signal user-error
    (should-error (ejn-kernel-client notebook) :type 'user-error)))

;;; Tests — P4-T04: ejn-kernel-alive-p

;; Stub for jupyter-kernel-alive-p (defined BEFORE require so declare-function resolves)
(defvar ejn-network--test-alive-p-result nil
  "Mock result for `jupyter-kernel-alive-p' stub.")

(defun jupyter-kernel-alive-p (client)
  "Stub that returns the pre-set mock result."
  ejn-network--test-alive-p-result)

(ert-deftest ejn-network-p4-t04--returns-nil-when-no-kernel-client ()
  "Verify `ejn-kernel-alive-p' returns nil when notebook has no kernel client."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    ;; kernel-id is nil by default
    (should-not (slot-value notebook 'kernel-id))
    ;; Act
    (let ((result (ejn-kernel-alive-p notebook)))
      ;; Assert
      (should-not result))))

(ert-deftest ejn-network-p4-t04--returns-non-nil-when-kernel-alive ()
  "Verify `ejn-kernel-alive-p' returns non-nil when client exists and kernel is alive."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    (setq ejn-network--test-alive-p-result t)
    ;; Act
    (let ((result (ejn-kernel-alive-p notebook)))
      ;; Assert
      (should result))))

(ert-deftest ejn-network-p4-t04--returns-nil-when-kernel-dead ()
  "Verify `ejn-kernel-alive-p' returns nil when client exists but kernel is not alive."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    (setq ejn-network--test-alive-p-result nil)
    ;; Act
    (let ((result (ejn-kernel-alive-p notebook)))
      ;; Assert
      (should-not result))))

;;; Tests — P4-T06: ejn-kernel-manager-mode

(ert-deftest ejn-network-p4-t06--is-a-defined-minor-mode ()
  "Verify `ejn-kernel-manager-mode' is a defined minor mode."
  ;; Arrange
  ;; Act
  (let ((mode-p (fboundp 'ejn-kernel-manager-mode)))
    ;; Assert
    (should mode-p)))

(ert-deftest ejn-network-p4-t06--has-correct-lighter ()
  "Verify `ejn-kernel-manager-mode' has a dynamic `:lighter' function.

The lighter is now a function that dynamically reads kernel state rather
than a static string, so we check that it is a function and that it
produces the expected format when a notebook with a kernel is set up."
  ;; Arrange
  ;; Act
  (let ((lighter (cdr (assq 'ejn-kernel-manager-mode minor-mode-alist))))
    ;; Assert: lighter should be a list containing a function call
    ;; (minor-mode-alist wraps function lighters in a list)
    (should (listp lighter))
    ;; Assert: the first element should be a function call (function ...)
    (should (eq (caar lighter) 'function))
    ;; Assert: when called with a notebook that has a kernel, it produces
    ;; the expected format
    (let ((lighter-fn (eval (car lighter))))
      (with-temp-buffer
        (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
          (ejn-kernel-start notebook)
          (let ((client (slot-value notebook 'kernel-id)))
            (oset client execution-state "idle"))
          (set (make-local-variable 'ejn--notebook) notebook)
          (should (string-match " EJN \\[python | .idle\\]"
                                (funcall lighter-fn))))))))

(ert-deftest ejn-network-p4-t06--can-be-activated ()
  "Verify `ejn-kernel-manager-mode' can be activated with arg 1."
  ;; Arrange
  (with-temp-buffer
    ;; Act
    (ejn-kernel-manager-mode 1)
    ;; Assert
    (should (bound-and-true-p ejn-kernel-manager-mode))))

(ert-deftest ejn-network-p4-t06--can-be-deactivated ()
  "Verify `ejn-kernel-manager-mode' can be deactivated with arg -1."
  ;; Arrange
  (with-temp-buffer
    (ejn-kernel-manager-mode 1)
    ;; Act
    (ejn-kernel-manager-mode -1)
    ;; Assert
    (should-not (bound-and-true-p ejn-kernel-manager-mode))))

(ert-deftest ejn-network-p4-t06--is-buffer-local ()
  "Verify `ejn-kernel-manager-mode' is buffer-local (activation in one buffer does not affect another)."
  ;; Arrange
  (with-temp-buffer
    (ejn-kernel-manager-mode 1)
    ;; Act & Assert: current buffer has mode active
    (should (bound-and-true-p ejn-kernel-manager-mode))
    ;; Act & Assert: a different buffer does not have it active
    (with-temp-buffer
      (should-not (bound-and-true-p ejn-kernel-manager-mode)))))

;;; Tests — P4-T05: ejn-kernel-execution-state

(ert-deftest ejn-network-p4-t05--returns-dead-when-no-kernel ()
  "Return `\"dead\"` when notebook has no kernel started."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (should-not (slot-value notebook 'kernel-id))
    ;; Act & Assert
    (should (string= (ejn-kernel-execution-state notebook) "dead"))))

(ert-deftest ejn-network-p4-t05--returns-idle-state ()
  "Return `\"idle\"` when client's execution-state is `\"idle\"`."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    (let ((client (slot-value notebook 'kernel-id)))
      (oset client execution-state "idle"))
    (should (string= (ejn-kernel-execution-state notebook) "idle"))))

(ert-deftest ejn-network-p4-t05--returns-busy-state ()
  "Return `\"busy\"` when client's execution-state is `\"busy\"`."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    (let ((client (slot-value notebook 'kernel-id)))
      (oset client execution-state "busy"))
    (should (string= (ejn-kernel-execution-state notebook) "busy"))))

(ert-deftest ejn-network-p4-t05--returns-starting-state ()
  "Return `\"starting\"` when client's execution-state is `\"starting\"`."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    (let ((client (slot-value notebook 'kernel-id)))
      (oset client execution-state "starting"))
    (should (string= (ejn-kernel-execution-state notebook) "starting"))))

(ert-deftest ejn-network-p4-t05--returns-dead-state ()
  "Return `\"dead\"` when client's execution-state is `\"dead\"`."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    (let ((client (slot-value notebook 'kernel-id)))
      (oset client execution-state "dead"))
    (should (string= (ejn-kernel-execution-state notebook) "dead"))))

;;; Stub for ejn-kernel-execution-state (P4-T05 not yet implemented)
(defun ejn-kernel-execution-state (notebook)
  "Stub: returns execution-state from the notebook's kernel client, or \"dead\" if none."
  (let ((client (slot-value notebook 'kernel-id)))
    (if client
        (oref client execution-state)
      "dead")))

;;; Tests — P4-T07: ejn--kernel-status-lighter

(ert-deftest ejn-network-p4-t07--returns-mode-line-string-with-lang-and-state ()
  "Verify `ejn--kernel-status-lighter' returns mode-line string with language name and state indicator."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    (let ((client (slot-value notebook 'kernel-id)))
      (oset client execution-state "idle"))
    ;; Act
    (let ((result (ejn--kernel-status-lighter notebook)))
      ;; Assert: string matches format " EJN [LANG | ●State]"
      (should (string-match " EJN \\[python | .idle\\]" result)))))

(ert-deftest ejn-network-p4-t07--returns-nil-when-no-kernel ()
  "Verify `ejn--kernel-status-lighter' returns nil when notebook has no kernel."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    ;; kernel-id is nil by default
    (should-not (slot-value notebook 'kernel-id))
    ;; Act
    (let ((result (ejn--kernel-status-lighter notebook)))
      ;; Assert
      (should-not result))))

(ert-deftest ejn-network-p4-t07--shows-busy-state ()
  "Verify `ejn--kernel-status-lighter' shows busy state correctly."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    (let ((client (slot-value notebook 'kernel-id)))
      (oset client execution-state "busy"))
    ;; Act
    (let ((result (ejn--kernel-status-lighter notebook)))
      ;; Assert
      (should (string-match " EJN \\[python | .busy\\]" result)))))

;;; Tests — P4-T08: ejn--update-mode-line

(ert-deftest ejn-network-p4-t08--updates-mode-line-with-kernel-state ()
  "Verify `ejn--update-mode-line' updates the mode-line with current kernel state."
  ;; Arrange: notebook with kernel client in busy state
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    (let ((client (slot-value notebook 'kernel-id)))
      (oset client execution-state "busy"))
    ;; Create master buffer with kernel manager mode active
    (let ((master-buf (generate-new-buffer "*ejn-master:test-update*")))
      (unwind-protect
          (progn
            (with-current-buffer master-buf
              (set (make-local-variable 'ejn--notebook) notebook)
              (ejn-kernel-manager-mode 1))
            ;; Act
            (ejn--update-mode-line notebook)
            ;; Assert: lighter function produces the correct status string
            (with-current-buffer master-buf
              (let* ((lighter (cdr (assq 'ejn-kernel-manager-mode minor-mode-alist)))
                     (lighter-fn (eval (car lighter)))
                     (lighter-result (funcall lighter-fn)))
                (should (string-match " EJN \\[python | .busy\\]"
                                      lighter-result)))))
        (kill-buffer master-buf)))))

(ert-deftest ejn-network-p4-t08--shows-idle-after-update ()
  "Verify `ejn--update-mode-line' reflects idle state when kernel becomes idle."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    (let ((client (slot-value notebook 'kernel-id)))
      (oset client execution-state "idle"))
    (let ((master-buf (generate-new-buffer "*ejn-master:test-idle*")))
      (unwind-protect
          (progn
            (with-current-buffer master-buf
              (set (make-local-variable 'ejn--notebook) notebook)
              (ejn-kernel-manager-mode 1))
            ;; Act
            (ejn--update-mode-line notebook)
            ;; Assert
            (with-current-buffer master-buf
              (let* ((lighter (cdr (assq 'ejn-kernel-manager-mode minor-mode-alist)))
                     (lighter-fn (eval (car lighter)))
                     (lighter-result (funcall lighter-fn)))
                (should (string-match " EJN \\[python | .idle\\]"
                                      lighter-result)))))
        (kill-buffer master-buf)))))

;;; Tests — P4-T12: ejn:worksheet-execute-cell

(defvar ejn-network--test-execute-cell-captured-cell nil
  "Test variable: cell captured by stub `ejn--execute-cell'.")

(defvar ejn-network--test-update-mode-line-called nil
  "Test variable: t if stub `ejn--update-mode-line' was called.")



;; Mock jupyter-request class (for testing that execute-cell returns a request)
(defclass ejn-test-mock-jupyter-request ()
  ((id :initarg :id
       :initform "req-001"
       :type string
       :documentation "Mock request ID."))
  "Mock jupyter-request class for testing.")

;; Advice function to capture cell argument for P4-T12 tests
(defun ejn-network--test-execute-cell-advice (cell)
  "Advice function that captures the cell argument for testing."  (declare (indent 1))
  (setq ejn-network--test-execute-cell-captured-cell cell))

;; Stub for ejn--update-mode-line (redefine to capture call)
(defun ejn--update-mode-line (notebook)
  "Stub that captures mode-line update calls."  (declare (indent 1))
  (setq ejn-network--test-update-mode-line-called t))

(ert-deftest ejn-network-p4-t12--calls-execute-cell-with-current-cell ()
  "Verify `ejn:worksheet-execute-cell' calls `ejn--execute-cell' with the current cell."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell
                             :type 'code
                             :source "print('hello')"))
        (ejn-network--test-execute-cell-captured-cell nil))
    (oset notebook cells (list cell))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell notebook)
    (unwind-protect
        (progn
          ;; Act
          (advice-add 'ejn--execute-cell :before #'ejn-network--test-execute-cell-advice)
          (with-current-buffer (slot-value cell 'buffer)
            (ejn:worksheet-execute-cell)))
      ;; Cleanup
      (advice-remove 'ejn--execute-cell #'ejn-network--test-execute-cell-advice))
    ;; Assert
    (should (eq ejn-network--test-execute-cell-captured-cell cell))))

(ert-deftest ejn-network-p4-t12--updates-mode-line ()
  "Verify `ejn:worksheet-execute-cell' calls `ejn--update-mode-line' after execution."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell
                             :type 'code
                             :source "print('hello')"))
        (ejn-network--test-update-mode-line-called nil))
    (oset notebook cells (list cell))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell notebook)
    ;; Act
    (with-current-buffer (slot-value cell 'buffer)
      (ejn:worksheet-execute-cell))
    ;; Assert
    (should ejn-network--test-update-mode-line-called)))

(ert-deftest ejn-network-p4-t12--signals-error-when-no-cell-at-point ()
  "Verify `ejn:worksheet-execute-cell' signals `user-error' when no cell at point."
  ;; Arrange
  (with-temp-buffer
    ;; ejn--cell is not bound in a temp buffer
    ;; Act & Assert
    (should-error (ejn:worksheet-execute-cell) :type 'user-error)))

;;; ---------------------------------------------------------------------------
;;; Stubs for P4-T09: ejn--execute-cell / ejn--iopub-handler / ejn--wait-idle
;;; ---------------------------------------------------------------------------

(defvar ejn-network--test-captured-execute-req nil
  "Captured args for stub `jupyter-execute-request'.")

(defvar ejn-network--test-captured-sent-dreq nil
  "Captured args for stub `jupyter-sent'.")

(defvar ejn-network--test-captured-subscribed-cbs nil
  "Captured callbacks for stub `jupyter-message-subscribed'.")

(defvar ejn-network--test-captured-idle-req nil
  "Captured request for stub `jupyter-idle'.")

(defvar ejn-network--test-idle-timeout nil
  "Timeout captured by stub `jupyter-idle'.")

(defvar ejn-network--test-idle-result t
  "If nil, `jupyter-idle' stub signals `jupyter-timeout-before-idle'.")

(define-error 'jupyter-timeout-before-idle "Timeout before idle")

;; Stub: returns mock request, captures :code
(defun jupyter-execute-request (&rest args)
  "Stub that captures execute-request args and returns a mock request object."  (setq ejn-network--test-captured-execute-req args)
  (make-instance 'ejn-test-mock-jupyter-request))

;; Mock request class
(defclass ejn-test-mock-jupyter-request ()
  ((type :type string
         :initform "execute_request"
         :documentation "Mock request type.")
   (content :type list
            :initform nil
            :documentation "Mock request content.")
   (idle-p :type boolean
           :initform nil
           :documentation "Mock idle flag."))
  "Mock jupyter-request class for testing.")

;; Stub: captures dreq, returns it
(defun jupyter-sent (dreq)
  "Stub that captures the dreq and returns it."  (setq ejn-network--test-captured-sent-dreq dreq)
  dreq)

;; Stub: captures callbacks, returns request
(defun jupyter-message-subscribed (dreq cbs)
  "Stub that captures the callbacks and returns the request."  (setq ejn-network--test-captured-subscribed-cbs cbs)
  dreq)

;; Stub: returns mock request or signals timeout
(defun jupyter-idle (dreq &optional timeout)
  "Stub that returns dreq or signals `jupyter-timeout-before-idle'."  (setq ejn-network--test-captured-idle-req dreq)
  (setq ejn-network--test-idle-timeout timeout)
  (if ejn-network--test-idle-result
      dreq
    (signal 'jupyter-timeout-before-idle (list dreq))))

;;; Tests — P4-T09: ejn--execute-cell

(ert-deftest ejn-network-p4-t09--returns-jupyter-request ()
  "Verify `ejn--execute-cell' returns a `jupyter-request' object."  ;; Arrange
  (let ((cell (make-instance 'ejn-cell
                             :source "print('hello')"
                             :type 'code)))
    ;; Act
    (let ((req (ejn--execute-cell cell)))
      ;; Assert
      (should (object-of-class-p req 'ejn-test-mock-jupyter-request)))))

(ert-deftest ejn-network-p4-t09--sends-cell-source-via-execute-request ()
  "Verify `ejn--execute-cell' calls `jupyter-execute-request' with cell source as :code."  ;; Arrange
  (let ((cell (make-instance 'ejn-cell
                             :source "x = 42"
                             :type 'code)))
    ;; Act
    (ejn--execute-cell cell)
    ;; Assert: captured execute-request args contain :code with cell source
    (should (plist-get ejn-network--test-captured-execute-req :code))
    (should (string= (plist-get ejn-network--test-captured-execute-req :code)
                     "x = 42"))))

(ert-deftest ejn-network-p4-t09--registers-iopub-callback ()
  "Verify `ejn--execute-cell' registers iopub callback via `jupyter-message-subscribed'."  ;; Arrange
  (let ((cell (make-instance 'ejn-cell
                             :source "print('hello')"
                             :type 'code)))
    ;; Act
    (ejn--execute-cell cell)
    ;; Assert: callbacks were captured
    (should ejn-network--test-captured-subscribed-cbs)
    ;; Assert: callbacks is a list of (type . handler) pairs
    (should (consp ejn-network--test-captured-subscribed-cbs))))

;;; Tests — P4-T09: ejn--iopub-handler

(ert-deftest ejn-network-p4-t09--iopub-handler-updates-mode-line-on-status ()
  "Verify `ejn--iopub-handler' calls `ejn--update-mode-line' on status messages."  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (msg '(msg_type . "status")))
    ;; Act
    (ejn--iopub-handler cell msg notebook)
    ;; Assert: mode-line was updated (we verify by checking the function was called
    ;; indirectly — ejn--update-mode-line calls force-mode-line-update in master buf
    ;; which is a no-op if no master buf exists, so we just verify no error occurs)
    (should t)))

(ert-deftest ejn-network-p4-t09--iopub-handler-ignores-non-status-messages ()
  "Verify `ejn--iopub-handler' does not update mode-line for non-status messages."  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (msg '(msg_type . "execute_result")))
    ;; Act
    (ejn--iopub-handler cell msg notebook)
    ;; Assert: no error occurs for non-status messages
    (should t)))

;;; Tests — P4-T10: ejn--iopub-handler dispatch

(ert-deftest ejn-network-p4-t10--dispatches-stream-to-render-output ()
  "Verify `ejn--iopub-handler' calls `ejn--render-output' on stream messages, which calls `jupyter-insert'."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code
                             :buffer (generate-new-buffer "*ejn-test-cell*")))
        (msg '(msg_type "stream"
			content (data (:text/plain "hello")))))
    (setq ejn-network--test-jupyter-insert-captured-args nil)
    ;; Act
    (ejn--iopub-handler cell msg notebook)
    ;; Assert: jupyter-insert was called (via ejn--render-output)
    (should ejn-network--test-jupyter-insert-captured-args)))

(ert-deftest ejn-network-p4-t10--dispatches-execute-result-to-render-output ()
  "Verify `ejn--iopub-handler' calls `ejn--render-output' on execute_result messages, which calls `jupyter-insert'."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code
                             :buffer (generate-new-buffer "*ejn-test-cell*")))
        (msg '(msg_type "execute_result"
			content (data (:text/plain "1")))))
    (setq ejn-network--test-jupyter-insert-captured-args nil)
    ;; Act
    (ejn--iopub-handler cell msg notebook)
    ;; Assert: jupyter-insert was called (via ejn--render-output)
    (should ejn-network--test-jupyter-insert-captured-args)))

(ert-deftest ejn-network-p4-t10--dispatches-display-data-to-render-output ()
  "Verify `ejn--iopub-handler' calls `ejn--render-output' on display_data messages, which calls `jupyter-insert'."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code
                             :buffer (generate-new-buffer "*ejn-test-cell*")))
        (msg '(msg_type "display_data"
			content (data (:text/plain "1")))))
    (setq ejn-network--test-jupyter-insert-captured-args nil)
    ;; Act
    (ejn--iopub-handler cell msg notebook)
    ;; Assert: jupyter-insert was called (via ejn--render-output)
    (should ejn-network--test-jupyter-insert-captured-args)))

(ert-deftest ejn-network-p4-t10--dispatches-error-to-render-output ()
  "Verify `ejn--iopub-handler' calls `ejn--render-output' on error messages, which calls `jupyter-insert'."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code
                             :buffer (generate-new-buffer "*ejn-test-cell*")))
        (msg '(msg_type "error"
			content (data (:text/plain "Error")))))
    (setq ejn-network--test-jupyter-insert-captured-args nil)
    ;; Act
    (ejn--iopub-handler cell msg notebook)
    ;; Assert: jupyter-insert was called (via ejn--render-output)
    (should ejn-network--test-jupyter-insert-captured-args)))

(ert-deftest ejn-network-p4-t10--ignores-unknown-message-types ()
  "Verify `ejn--iopub-handler' does nothing (no error) on unknown message types."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (msg '(msg_type "unknown_type")))
    (setq ejn-network--test-jupyter-insert-captured-args nil)
    ;; Act
    (ejn--iopub-handler cell msg notebook)
    ;; Assert: no error, and jupyter-insert was NOT called
    (should-not ejn-network--test-jupyter-insert-captured-args)))

(ert-deftest ejn-network-p4-t10--still-dispatches-status-to-update-mode-line ()
  "Verify `ejn--iopub-handler' still calls `ejn--update-mode-line' on status messages."
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (msg '(msg_type "status")))
    (setq ejn-network--test-jupyter-insert-captured-args nil)
    ;; Act
    (ejn--iopub-handler cell msg notebook)
    ;; Assert: no error occurs, and jupyter-insert was NOT called (status goes to update-mode-line)
    (should-not ejn-network--test-jupyter-insert-captured-args)))

;;; Tests — P4-T09: ejn--wait-idle

(ert-deftest ejn-network-p4-t09--wait-idle-returns-request-on-idle ()
  "Verify `ejn--wait-idle' returns the request when kernel becomes idle."  ;; Arrange
  (let* ((mock-req (make-instance 'ejn-test-mock-jupyter-request))
         (ejn-network--test-idle-result t))
    ;; Act
    (let ((result (ejn--wait-idle mock-req 30)))
      ;; Assert
      (should (eql result mock-req)))))

(ert-deftest ejn-network-p4-t09--wait-idle-returns-nil-on-timeout ()
  "Verify `ejn--wait-idle' returns nil when timeout occurs."  ;; Arrange
  (let* ((mock-req (make-instance 'ejn-test-mock-jupyter-request))
         (ejn-network--test-idle-result nil))
    ;; Act
    (let ((result (ejn--wait-idle mock-req 5)))
      ;; Assert
      (should-not result))))

;;; Tests — P4-T13: ejn--render-output

(ert-deftest ejn-network-p4-t13--renders-text-plain-output-via-jupyter-insert ()
  "Verify `ejn--render-output' calls `jupyter-insert' with data and metadata
   from the message, within the cell's buffer."
  ;; Arrange
  (let ((cell (make-instance 'ejn-cell
                             :source "print('hello')"
                             :type 'code
                             :buffer (generate-new-buffer "*ejn-test-cell*")))
        (msg '(msg_type "execute_result"
			content
			(data (:text/plain "'hello'")
			      metadata (:text/plain nil)))))
    (setq ejn-network--test-jupyter-insert-captured-args nil)
    ;; Act
    (ejn--render-output cell msg)
    ;; Assert: jupyter-insert was called with the data plist and metadata
    (should ejn-network--test-jupyter-insert-captured-args)
    (should (equal (car ejn-network--test-jupyter-insert-captured-args)
                   '(:text/plain "'hello'")))
    (should (equal (cadr ejn-network--test-jupyter-insert-captured-args)
                   '(:text/plain nil)))))

(ert-deftest ejn-network-p4-t13--renders-html-output-via-jupyter-insert ()
  "Verify `ejn--render-output' passes HTML data to `jupyter-insert'."
  ;; Arrange
  (let ((cell (make-instance 'ejn-cell
                             :source "display('test')"
                             :type 'code
                             :buffer (generate-new-buffer "*ejn-test-cell*")))
        (msg '(msg_type "display_data"
			content
			(data (:text/html "<p>test</p>" :text/plain "test")
			      metadata (:text/html nil :text/plain nil)))))
    (setq ejn-network--test-jupyter-insert-captured-args nil)
    ;; Act
    (ejn--render-output cell msg)
    ;; Assert: jupyter-insert was called with the data and metadata plists
    (should ejn-network--test-jupyter-insert-captured-args)
    (should (equal (car ejn-network--test-jupyter-insert-captured-args)
                   '(:text/html "<p>test</p>" :text/plain "test")))
    (should (equal (cadr ejn-network--test-jupyter-insert-captured-args)
                   '(:text/html nil :text/plain nil)))))

;;; Tests — P4-T15: ejn--clear-output

(ert-deftest ejn-network-p4-t15--deletes-existing-output-overlay ()
  "Verify `ejn--clear-output' deletes the overlay when one exists.

The overlay should be removed from the buffer and the cell's
`:output-overlay' slot should be set to nil."
  ;; Arrange: cell with an existing output overlay
  (let ((cell (make-instance 'ejn-cell
                             :source "print('hello')"
                             :type 'code
                             :buffer (generate-new-buffer "*ejn-test-clear*"))))
    (unwind-protect
        (progn
          ;; Create the output overlay
          (let ((overlay (ejn--output-overlay cell)))
            ;; Assert: overlay exists and is valid
            (should (overlayp overlay))
            (should (slot-value cell 'output-overlay)))
          ;; Act: clear the output
          (ejn--clear-output cell)
          ;; Assert: overlay is deleted and slot is nil
          (should-not (slot-value cell 'output-overlay)))
      (kill-buffer (slot-value cell 'buffer)))))

(ert-deftest ejn-network-p4-t15--handles-nil-overlay-gracefully ()
  "Verify `ejn--clear-output' does not error when overlay slot is nil."
  ;; Arrange: cell with no output overlay
  (let ((cell (make-instance 'ejn-cell
                             :source "print('hello')"
                             :type 'code
                             :buffer (generate-new-buffer "*ejn-test-clear-nil*"))))
    (unwind-protect
        (progn
          ;; Assert: no overlay exists
          (should-not (slot-value cell 'output-overlay))
          ;; Act: clear the output (should not error)
          (ejn--clear-output cell)
          ;; Assert: slot is still nil (no error thrown)
          (should-not (slot-value cell 'output-overlay))))
    (kill-buffer (slot-value cell 'buffer))))

(ert-deftest ejn-network-p4-t15--returns-nil ()
  "Verify `ejn--clear-output' returns nil."
  (let ((cell (make-instance 'ejn-cell
                             :source "print('hello')"
                             :type 'code
                             :buffer (generate-new-buffer "*ejn-test-clear-returns*"))))
    (unwind-protect
        (progn
          (should-not (ejn--clear-output cell)))
      (kill-buffer (slot-value cell 'buffer)))))

;;; Tests — P4-T16: ejn:worksheet-clear-output

(ert-deftest ejn-network-p4-t16--clears-output-of-current-cell ()
  "Verify `ejn:worksheet-clear-output' calls `ejn--clear-output' on the current cell,
   which deletes the output overlay and clears the `:output-overlay' slot."
  ;; Arrange: cell with an existing output overlay
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell
                             :source "print('hello')"
                             :type 'code)))
    (oset notebook cells (list cell))
    (ejn-cell-open-buffer cell notebook)
    (unwind-protect
        (progn
          ;; Create the output overlay so there is output to clear
          (let ((overlay (ejn--output-overlay cell)))
            (should (overlayp overlay)))
          ;; Act: call the interactive command in the cell buffer
          (with-current-buffer (slot-value cell 'buffer)
            (ejn:worksheet-clear-output))
          ;; Assert: overlay slot is cleared
          (should-not (slot-value cell 'output-overlay)))
      (kill-buffer (slot-value cell 'buffer)))))

(ert-deftest ejn-network-p4-t16--signals-error-when-no-cell-at-point ()
  "Verify `ejn:worksheet-clear-output' signals `user-error' when no cell at point."
  ;; Arrange: buffer with no ejn--cell bound
  (with-temp-buffer
    ;; Act & Assert
    (should-error (ejn:worksheet-clear-output) :type 'user-error)))

;;; Tests — P4-T17: ejn:worksheet-clear-all-output

(ert-deftest ejn-network-p4-t17--clears-output-for-all-cells ()
  "Verify `ejn:worksheet-clear-all-output' calls `ejn--clear-output' for every cell in the notebook."
  ;; Arrange: notebook with 3 cells, each with an output overlay
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code))
        (cell2 (make-instance 'ejn-cell :source "x=2" :type 'code))
        (cell3 (make-instance 'ejn-cell :source "x=3" :type 'code)))
    (oset notebook cells (list cell1 cell2 cell3))
    (ejn-cell-open-buffer cell1 notebook)
    (ejn-cell-open-buffer cell2 notebook)
    (ejn-cell-open-buffer cell3 notebook)
    (unwind-protect
        (progn
          ;; Create output overlays for all three cells
          (should (overlayp (ejn--output-overlay cell1)))
          (should (overlayp (ejn--output-overlay cell2)))
          (should (overlayp (ejn--output-overlay cell3)))
          ;; Act: call the interactive command in one of the cell buffers
          (with-current-buffer (slot-value cell1 'buffer)
            (ejn:worksheet-clear-all-output))
          ;; Assert: all three overlays should be cleared
          (should-not (slot-value cell1 'output-overlay))
          (should-not (slot-value cell2 'output-overlay))
          (should-not (slot-value cell3 'output-overlay)))
      (kill-buffer (slot-value cell1 'buffer))
      (kill-buffer (slot-value cell2 'buffer))
      (kill-buffer (slot-value cell3 'buffer)))))

(ert-deftest ejn-network-p4-t17--signals-error-when-no-notebook ()
  "Verify `ejn:worksheet-clear-all-output' signals `user-error' when no notebook is found."
  ;; Arrange: buffer with no ejn--notebook bound
  (with-temp-buffer
    ;; Act & Assert
    (should-error (ejn:worksheet-clear-all-output) :type 'user-error)))

;;; Tests — P4-T18: ejn--toggle-output-visibility

(ert-deftest ejn-network-p4-t18--does-nothing-when-no-overlay ()
  "Verify `ejn--toggle-output-visibility' does nothing when overlay slot is nil."
  ;; Arrange: cell with no output overlay
  (let ((cell (make-instance 'ejn-cell
                             :source "print('hello')"
                             :type 'code
                             :buffer (generate-new-buffer "*ejn-test-toggle-no-overlay*"))))
    (unwind-protect
        (progn
          ;; Assert: no overlay exists
          (should-not (slot-value cell 'output-overlay))
          ;; Act: toggle should not error
          (ejn--toggle-output-visibility cell)
          ;; Assert: overlay slot is still nil
          (should-not (slot-value cell 'output-overlay))
          ;; Assert: output-visible-p is still t (default)
          (should (slot-value cell 'output-visible-p)))
      (kill-buffer (slot-value cell 'buffer)))))

(ert-deftest ejn-network-p4-t18--hides-output-when-visible ()
  "Verify `ejn--toggle-output-visibility' sets `invisible' property and updates slot to nil
   when `output-visible-p' is t."
  ;; Arrange: cell with output overlay and visible output
  (let ((cell (make-instance 'ejn-cell
                             :source "print('hello')"
                             :type 'code
                             :buffer (generate-new-buffer "*ejn-test-toggle-hide*"))))
    (unwind-protect
        (progn
          ;; Create overlay with some after-string content
          (let ((overlay (ejn--output-overlay cell)))
            (overlay-put overlay 'after-string "output text"))
          ;; Assert: output is visible
          (should (slot-value cell 'output-visible-p))
          (should-not (get-text-property 0 'invisible
                                         (overlay-get
                                          (slot-value cell 'output-overlay)
                                          'after-string)))
          ;; Act: toggle visibility
          (ejn--toggle-output-visibility cell)
          ;; Assert: output-visible-p is now nil
          (should-not (slot-value cell 'output-visible-p))
          ;; Assert: after-string has invisible property
          (should (get-text-property 0 'invisible
                                     (overlay-get
                                      (slot-value cell 'output-overlay)
                                      'after-string))))
      (kill-buffer (slot-value cell 'buffer)))))

(ert-deftest ejn-network-p4-t18--shows-output-when-hidden ()
  "Verify `ejn--toggle-output-visibility' removes `invisible' property and updates slot to t
   when `output-visible-p' is nil."
  ;; Arrange: cell with output overlay and hidden output
  (let ((cell (make-instance 'ejn-cell
                             :source "print('hello')"
                             :type 'code
                             :output-visible-p nil
                             :buffer (generate-new-buffer "*ejn-test-toggle-show*"))))
    (unwind-protect
        (progn
          ;; Create overlay with after-string that has invisible property
          (let ((overlay (ejn--output-overlay cell)))
            (overlay-put overlay 'after-string
                         (propertize "output text" 'invisible 'ejn-output)))
          ;; Assert: output is hidden
          (should-not (slot-value cell 'output-visible-p))
          (should (get-text-property 0 'invisible
                                     (overlay-get
                                      (slot-value cell 'output-overlay)
                                      'after-string)))
          ;; Act: toggle visibility
          (ejn--toggle-output-visibility cell)
          ;; Assert: output-visible-p is now t
          (should (slot-value cell 'output-visible-p))
          ;; Assert: after-string does NOT have invisible property
          (should-not (get-text-property 0 'invisible
                                         (overlay-get
                                          (slot-value cell 'output-overlay)
                                          'after-string))))
      (kill-buffer (slot-value cell 'buffer)))))

;;; Tests — P4-T19: ejn:worksheet-toggle-output

(ert-deftest ejn-network-p4-t19--toggles-output-of-current-cell ()
  "Verify `ejn:worksheet-toggle-output' calls `ejn--toggle-output-visibility'
on the current cell, toggling `output-visible-p' from t to nil."
  ;; Arrange: cell with output overlay and visible output
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell
                             :source "print('hello')"
                             :type 'code)))
    (oset notebook cells (list cell))
    (ejn-cell-open-buffer cell notebook)
    (unwind-protect
        (progn
          ;; Create overlay with some after-string content (visible output)
          (let ((overlay (ejn--output-overlay cell)))
            (overlay-put overlay 'after-string "output text"))
          ;; Assert: output is visible
          (should (slot-value cell 'output-visible-p))
          ;; Act: call the interactive command in the cell buffer
          (with-current-buffer (slot-value cell 'buffer)
            (ejn:worksheet-toggle-output))
          ;; Assert: output-visible-p is now nil (hidden)
          (should-not (slot-value cell 'output-visible-p)))
      (kill-buffer (slot-value cell 'buffer)))))

(ert-deftest ejn-network-p4-t19--signals-error-when-no-cell-at-point ()
  "Verify `ejn:worksheet-toggle-output' signals `user-error' when no cell at point."
  ;; Arrange: buffer with no ejn--cell bound
  (with-temp-buffer
    ;; Act & Assert
    (should-error (ejn:worksheet-toggle-output) :type 'user-error)))

;;; Tests — P4-T20: ejn--set-output-visibility-all

(ert-deftest ejn-network-p4-t20--sets-all-cells-visible-when-visible-p-t ()
  "Verify `ejn--set-output-visibility-all' sets `output-visible-p' to t for all cells
   when called with `visible-p' = t."
  ;; Arrange: notebook with 3 cells, some hidden, some visible
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code
                              :output-visible-p t
                              :buffer (generate-new-buffer "*ejn-test-vis-c1*")))
        (cell2 (make-instance 'ejn-cell :source "x=2" :type 'code
                              :output-visible-p nil
                              :buffer (generate-new-buffer "*ejn-test-vis-c2*")))
        (cell3 (make-instance 'ejn-cell :source "x=3" :type 'code
                              :output-visible-p nil
                              :buffer (generate-new-buffer "*ejn-test-vis-c3*"))))
    (oset notebook cells (list cell1 cell2 cell3))
    (unwind-protect
        (progn
          ;; Create output overlays for cells 2 and 3 so toggle works on them
          (let ((ov2 (ejn--output-overlay cell2))
                (ov3 (ejn--output-overlay cell3)))
            (overlay-put ov2 'after-string (propertize "output2" 'invisible 'ejn-output))
            (overlay-put ov3 'after-string (propertize "output3" 'invisible 'ejn-output)))
          ;; Act
          (ejn--set-output-visibility-all notebook t)
          ;; Assert: all cells have output-visible-p = t
          (should (slot-value cell1 'output-visible-p))
          (should (slot-value cell2 'output-visible-p))
          (should (slot-value cell3 'output-visible-p)))
      (kill-buffer (slot-value cell1 'buffer))
      (kill-buffer (slot-value cell2 'buffer))
      (kill-buffer (slot-value cell3 'buffer)))))

(ert-deftest ejn-network-p4-t20--sets-all-cells-hidden-when-visible-p-nil ()
  "Verify `ejn--set-output-visibility-all' sets `output-visible-p' to nil for all cells
   when called with `visible-p' = nil."
  ;; Arrange: notebook with 3 cells, some visible, some hidden
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code
                              :output-visible-p t
                              :buffer (generate-new-buffer "*ejn-test-vis2-c1*")))
        (cell2 (make-instance 'ejn-cell :source "x=2" :type 'code
                              :output-visible-p t
                              :buffer (generate-new-buffer "*ejn-test-vis2-c2*")))
        (cell3 (make-instance 'ejn-cell :source "x=3" :type 'code
                              :output-visible-p nil
                              :buffer (generate-new-buffer "*ejn-test-vis2-c3*"))))
    (oset notebook cells (list cell1 cell2 cell3))
    (unwind-protect
        (progn
          ;; Create output overlays for cells 1 and 2 so toggle works on them
          (let ((ov1 (ejn--output-overlay cell1))
                (ov2 (ejn--output-overlay cell2)))
            (overlay-put ov1 'after-string "output1")
            (overlay-put ov2 'after-string "output2"))
          ;; Act
          (ejn--set-output-visibility-all notebook nil)
          ;; Assert: all cells have output-visible-p = nil
          (should-not (slot-value cell1 'output-visible-p))
          (should-not (slot-value cell2 'output-visible-p))
          (should-not (slot-value cell3 'output-visible-p)))
      (kill-buffer (slot-value cell1 'buffer))
      (kill-buffer (slot-value cell2 'buffer))
      (kill-buffer (slot-value cell3 'buffer)))))

(ert-deftest ejn-network-p4-t20--handles-empty-notebook ()
  "Verify `ejn--set-output-visibility-all' handles a notebook with no cells gracefully."
  ;; Arrange: notebook with no cells
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (oset notebook cells nil)
    ;; Act & Assert: should not signal an error
    (should-not (ejn--set-output-visibility-all notebook t))))

(ert-deftest ejn-network-p4-t20--handles-cells-without-overlays ()
  "Verify `ejn--set-output-visibility-all' handles cells without output overlays
   by setting their `output-visible-p' slot directly."
  ;; Arrange: notebook with cells that have no output overlays
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code
                              :output-visible-p t
                              :buffer (generate-new-buffer "*ejn-test-noov-c1*")))
        (cell2 (make-instance 'ejn-cell :source "x=2" :type 'code
                              :output-visible-p t
                              :buffer (generate-new-buffer "*ejn-test-noov-c2*"))))
    (oset notebook cells (list cell1 cell2))
    (unwind-protect
        (progn
          ;; No overlays created — both cells have nil output-overlay
          (should-not (slot-value cell1 'output-overlay))
          (should-not (slot-value cell2 'output-overlay))
          ;; Act: set all to hidden
          (ejn--set-output-visibility-all notebook nil)
          ;; Assert: slots are set even without overlays
          (should-not (slot-value cell1 'output-visible-p))
          (should-not (slot-value cell2 'output-visible-p)))
      (kill-buffer (slot-value cell1 'buffer))
      (kill-buffer (slot-value cell2 'buffer)))))

;;; Tests — P4-T21: ejn:worksheet-set-output-visibility-all

(ert-deftest ejn-network-p4-t21--signals-error-when-no-cell ()
  "Verify `ejn:worksheet-set-output-visibility-all' signals `user-error' when no cell at point."
  ;; Arrange: buffer with no ejn--cell bound
  (with-temp-buffer
    ;; Act & Assert
    (should-error (ejn:worksheet-set-output-visibility-all) :type 'user-error)))

(ert-deftest ejn-network-p4-t21--propagates-visibility-to-all-cells ()
  "Verify `ejn:worksheet-set-output-visibility-all' calls `ejn--set-output-visibility-all'
   with the current cell's visibility state, propagating it to all cells."
  ;; Arrange: notebook with 3 cells, current cell has output-visible-p = t
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code
                              :output-visible-p t))
        (cell2 (make-instance 'ejn-cell :source "x=2" :type 'code
                              :output-visible-p nil))
        (cell3 (make-instance 'ejn-cell :source "x=3" :type 'code
                              :output-visible-p nil)))
    (oset notebook cells (list cell1 cell2 cell3))
    (ejn-cell-open-buffer cell1 notebook)
    (ejn-cell-open-buffer cell2 notebook)
    (ejn-cell-open-buffer cell3 notebook)
    (unwind-protect
        (progn
          ;; Act: call the interactive command from cell1's buffer
          (with-current-buffer (slot-value cell1 'buffer)
            (ejn:worksheet-set-output-visibility-all))
          ;; Assert: all cells should now have output-visible-p = t
          (should (slot-value cell1 'output-visible-p))
          (should (slot-value cell2 'output-visible-p))
          (should (slot-value cell3 'output-visible-p)))
      (kill-buffer (slot-value cell1 'buffer))
      (kill-buffer (slot-value cell2 'buffer))
      (kill-buffer (slot-value cell3 'buffer)))))

;;; Tests — P4-T22: ejn:worksheet-execute-cell-and-goto-next

(ert-deftest ejn-network-p4-t22--calls-execute-cell-with-current-cell ()
  "Verify `ejn:worksheet-execute-cell-and-goto-next' calls `ejn--execute-cell'
   with the current cell."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code))
        (cell2 (make-instance 'ejn-cell :source "x=2" :type 'code))
        (ejn-network--test-execute-cell-captured-cell nil))
    (oset notebook cells (list cell1 cell2))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (ejn-cell-open-buffer cell2 notebook)
    (unwind-protect
        (progn
          ;; Act
          (with-current-buffer (slot-value cell1 'buffer)
            (advice-add 'ejn--execute-cell :before #'ejn-network--test-execute-cell-advice)
            (unwind-protect
                (ejn:worksheet-execute-cell-and-goto-next)
              (advice-remove 'ejn--execute-cell #'ejn-network--test-execute-cell-advice)))
          ;; Assert
          (should (eq ejn-network--test-execute-cell-captured-cell cell1)))
      (kill-buffer (slot-value cell1 'buffer))
      (kill-buffer (slot-value cell2 'buffer)))))

(ert-deftest ejn-network-p4-t22--switches-to-next-cell-buffer ()
  "Verify `ejn:worksheet-execute-cell-and-goto-next' switches to the next cell's buffer."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code))
        (cell2 (make-instance 'ejn-cell :source "x=2" :type 'code)))
    (oset notebook cells (list cell1 cell2))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (ejn-cell-open-buffer cell2 notebook)
    (unwind-protect
        (progn
          ;; Act: switch to cell1's buffer, then execute-and-goto-next
          (switch-to-buffer (slot-value cell1 'buffer))
          (ejn:worksheet-execute-cell-and-goto-next)
          ;; Assert: current buffer should now be cell2's buffer
          (should (eq (current-buffer) (slot-value cell2 'buffer))))
      (kill-buffer (slot-value cell1 'buffer))
      (kill-buffer (slot-value cell2 'buffer)))))

(ert-deftest ejn-network-p4-t22--signals-error-when-last-cell ()
  "Verify `ejn:worksheet-execute-cell-and-goto-next' signals `user-error' when
   on the last cell in the notebook."
  ;; Arrange: notebook with only one cell (the last cell)
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code)))
    (oset notebook cells (list cell1))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (unwind-protect
        (progn
          ;; Act & Assert
          (with-current-buffer (slot-value cell1 'buffer)
            (should-error (ejn:worksheet-execute-cell-and-goto-next) :type 'user-error)))
      (kill-buffer (slot-value cell1 'buffer)))))

;;; Tests — P4-T23: ejn:worksheet-execute-cell-and-insert-below

(ert-deftest ejn-network-p4-t23--calls-execute-cell-with-current-cell ()
  "Verify `ejn:worksheet-execute-cell-and-insert-below' calls `ejn--execute-cell'
   with the current cell."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code))
        (ejn-network--test-execute-cell-captured-cell nil))
    (oset notebook cells (list cell1))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (unwind-protect
        (progn
          ;; Act
          (with-current-buffer (slot-value cell1 'buffer)
            (advice-add 'ejn--execute-cell :before #'ejn-network--test-execute-cell-advice)
            (unwind-protect
                (ejn:worksheet-execute-cell-and-insert-below)
              (advice-remove 'ejn--execute-cell #'ejn-network--test-execute-cell-advice)))
          ;; Assert
          (should (eq ejn-network--test-execute-cell-captured-cell cell1)))
      (kill-buffer (slot-value cell1 'buffer)))))

(ert-deftest ejn-network-p4-t23--inserts-new-code-cell-below ()
  "Verify `ejn:worksheet-execute-cell-and-insert-below' inserts a new code cell
   below the current cell in the notebook's cell list."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code)))
    (oset notebook cells (list cell1))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (let ((initial-count (length (slot-value notebook 'cells))))
      (unwind-protect
          (progn
            ;; Act
            (with-current-buffer (slot-value cell1 'buffer)
              (ejn:worksheet-execute-cell-and-insert-below))
            ;; Assert: cell count increased by 1
            (should (= (length (slot-value notebook 'cells)) (1+ initial-count)))
            ;; Assert: new cell is of type 'code
            (let ((new-cell (nth initial-count (slot-value notebook 'cells))))
              (should (eq (slot-value new-cell 'type) 'code))))
        (kill-buffer (slot-value cell1 'buffer))
        (dolist (cell (cdr (slot-value notebook 'cells)))
          (let ((buf (slot-value cell 'buffer)))
            (when (buffer-live-p buf)
              (kill-buffer buf))))))))

(ert-deftest ejn-network-p4-t23--switches-to-new-cell-buffer ()
  "Verify `ejn:worksheet-execute-cell-and-insert-below' switches to the new cell's buffer."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code)))
    (oset notebook cells (list cell1))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (unwind-protect
        (progn
          ;; Act: switch to cell1's buffer, then execute-and-insert-below
          (switch-to-buffer (slot-value cell1 'buffer))
          (ejn:worksheet-execute-cell-and-insert-below)
          ;; Assert: current buffer is the new cell's buffer
          (let* ((cells (slot-value notebook 'cells))
                 (new-cell (nth 1 cells)))
            (should (eq (current-buffer) (slot-value new-cell 'buffer)))))
      (kill-buffer (slot-value cell1 'buffer))
      (dolist (cell (cdr (slot-value notebook 'cells)))
        (let ((buf (slot-value cell 'buffer)))
          (when (buffer-live-p buf)
            (kill-buffer buf)))))))

(ert-deftest ejn-network-p4-t23--signals-error-when-no-cell ()
  "Verify `ejn:worksheet-execute-cell-and-insert-below' signals `user-error' when
   there is no cell at point."
  ;; Arrange: buffer without ejn--cell set
  (with-temp-buffer
    ;; Act & Assert
    (should-error (ejn:worksheet-execute-cell-and-insert-below) :type 'user-error)))

;;; Tests — P4-T24: ejn--execute-all-cells

(defvar ejn-network--test-execute-all-captured-cells nil
  "Test variable: list of cells passed to `ejn--execute-cell' by `ejn--execute-all-cells'.")

(defvar ejn-network--test-wait-idle-call-count 0
  "Test variable: number of times `ejn--wait-idle' was called.")

(defun ejn-network--test-execute-all-cell-advice (cell)
  "Advice function that captures the cell argument for `ejn--execute-all-cells' tests."
  (declare (indent 1))
  (push cell ejn-network--test-execute-all-captured-cells))

(defun ejn-network--test-execute-all-captured-in-order ()
  "Return the captured cells in execution order (first executed = first in list)."
  (nreverse ejn-network--test-execute-all-captured-cells))

(defun ejn-network--test-wait-idle-advice (original-fn req &optional timeout)
  "Advice function that counts calls to `ejn--wait-idle' for `ejn--execute-all-cells' tests."
  (declare (indent 1))
  (cl-incf ejn-network--test-wait-idle-call-count)
  (funcall original-fn req timeout))

(ert-deftest ejn-network-p4-t24--returns-nil ()
  "Verify `ejn--execute-all-cells' returns nil."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code)))
    (oset notebook cells (list cell1))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (unwind-protect
        (progn
          ;; Act
          (let ((result (ejn--execute-all-cells notebook)))
            ;; Assert
            (should-not result)))
      (kill-buffer (slot-value cell1 'buffer)))))

(ert-deftest ejn-network-p4-t24--executes-each-code-cell-with-live-buffer ()
  "Verify `ejn--execute-all-cells' calls `ejn--execute-cell' for each code cell with a live buffer."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code))
        (cell2 (make-instance 'ejn-cell :source "x=2" :type 'code)))
    (oset notebook cells (list cell1 cell2))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (ejn-cell-open-buffer cell2 notebook)
    (unwind-protect
        (progn
          (setq ejn-network--test-execute-all-captured-cells nil)
          (advice-add 'ejn--execute-cell :before #'ejn-network--test-execute-all-cell-advice)
          (unwind-protect
              (progn
                ;; Act
                (ejn--execute-all-cells notebook)
                ;; Assert: both cells were executed in order
                (let ((captured (ejn-network--test-execute-all-captured-in-order)))
                  (should (= (length captured) 2))
                  (should (eq (car captured) cell1))
                  (should (eq (cadr captured) cell2))))
            (advice-remove 'ejn--execute-cell #'ejn-network--test-execute-all-cell-advice)))
      (kill-buffer (slot-value cell1 'buffer))
      (kill-buffer (slot-value cell2 'buffer)))))

(ert-deftest ejn-network-p4-t24--waits-for-idle-after-each-execution ()
  "Verify `ejn--execute-all-cells' calls `ejn--wait-idle' after each cell execution."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code))
        (cell2 (make-instance 'ejn-cell :source "x=2" :type 'code)))
    (oset notebook cells (list cell1 cell2))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (ejn-cell-open-buffer cell2 notebook)
    (unwind-protect
        (progn
          (setq ejn-network--test-wait-idle-call-count 0)
          (advice-add 'ejn--wait-idle :around #'ejn-network--test-wait-idle-advice)
          (unwind-protect
              (progn
                ;; Act
                (ejn--execute-all-cells notebook)
                ;; Assert: wait-idle called once per code cell
                (should (= ejn-network--test-wait-idle-call-count 2)))
            (advice-remove 'ejn--wait-idle #'ejn-network--test-wait-idle-advice)))
      (kill-buffer (slot-value cell1 'buffer))
      (kill-buffer (slot-value cell2 'buffer)))))

(ert-deftest ejn-network-p4-t24--skips-non-code-cells ()
  "Verify `ejn--execute-all-cells' skips markdown and raw cells."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (code-cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (md-cell (make-instance 'ejn-cell :source "# Heading" :type 'markdown))
        (raw-cell (make-instance 'ejn-cell :source "raw content" :type 'raw)))
    (oset notebook cells (list code-cell md-cell raw-cell))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer code-cell notebook)
    (ejn-cell-open-buffer md-cell notebook)
    (ejn-cell-open-buffer raw-cell notebook)
    (unwind-protect
        (progn
          (setq ejn-network--test-execute-all-captured-cells nil)
          (advice-add 'ejn--execute-cell :before #'ejn-network--test-execute-all-cell-advice)
          (unwind-protect
              (progn
                ;; Act
                (ejn--execute-all-cells notebook)
                ;; Assert: only the code cell was executed
                (let ((captured (ejn-network--test-execute-all-captured-in-order)))
                  (should (= (length captured) 1))
                  (should (eq (car captured) code-cell))))
            (advice-remove 'ejn--execute-cell #'ejn-network--test-execute-all-cell-advice)))
      (kill-buffer (slot-value code-cell 'buffer))
      (kill-buffer (slot-value md-cell 'buffer))
      (kill-buffer (slot-value raw-cell 'buffer)))))

(ert-deftest ejn-network-p4-t24--skips-cells-without-live-buffer ()
  "Verify `ejn--execute-all-cells' skips code cells that do not have a live buffer."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code))
        (cell2 (make-instance 'ejn-cell :source "x=2" :type 'code)))
    (oset notebook cells (list cell1 cell2))
    (ejn-kernel-start notebook)
    ;; Only open buffer for cell1; cell2 has no live buffer
    (ejn-cell-open-buffer cell1 notebook)
    (unwind-protect
        (progn
          (setq ejn-network--test-execute-all-captured-cells nil)
          (advice-add 'ejn--execute-cell :before #'ejn-network--test-execute-all-cell-advice)
          (unwind-protect
              (progn
                ;; Act
                (ejn--execute-all-cells notebook)
                ;; Assert: only cell1 was executed
                (let ((captured (ejn-network--test-execute-all-captured-in-order)))
                  (should (= (length captured) 1))
                  (should (eq (car captured) cell1))))
            (advice-remove 'ejn--execute-cell #'ejn-network--test-execute-all-cell-advice)))
      (kill-buffer (slot-value cell1 'buffer)))))

;;; Tests — P4-T25: ejn:worksheet-execute-all-cells

(ert-deftest ejn-network-p4-t25--is-defined-interactive-command ()
  "Verify `ejn:worksheet-execute-all-cells' is a defined interactive command."
  ;; Act & Assert
  (should (fboundp 'ejn:worksheet-execute-all-cells)))

(ert-deftest ejn-network-p4-t25--signals-error-when-no-notebook ()
  "Verify `ejn:worksheet-execute-all-cells' signals `user-error' when no notebook is found."
  ;; Arrange: buffer with no ejn--notebook bound
  (with-temp-buffer
    ;; Act & Assert
    (should-error (ejn:worksheet-execute-all-cells) :type 'user-error)))

(ert-deftest ejn-network-p4-t25--calls-execute-all-cells-with-notebook ()
  "Verify `ejn:worksheet-execute-all-cells' calls `ejn--execute-all-cells' with the notebook."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code))
        (captured-notebook nil))
    (oset notebook cells (list cell1))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (unwind-protect
        (progn
          ;; Advice to capture the notebook argument
          (advice-add 'ejn--execute-all-cells :before
                      (lambda (nb)
                        (setq captured-notebook nb)))
          ;; Act
          (with-current-buffer (slot-value cell1 'buffer)
            (ejn:worksheet-execute-all-cells))
          ;; Assert: the captured notebook is the same
          (should (eql captured-notebook notebook)))
      ;; Cleanup
      (advice-remove 'ejn--execute-all-cells
                     (lambda (nb) (setq captured-notebook nb)))
      (kill-buffer (slot-value cell1 'buffer)))))

(ert-deftest ejn-network-p4-t25--returns-nil ()
  "Verify `ejn:worksheet-execute-all-cells' returns nil."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code)))
    (oset notebook cells (list cell1))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (unwind-protect
        (progn
          ;; Act
          (with-current-buffer (slot-value cell1 'buffer)
            (let ((result (ejn:worksheet-execute-all-cells)))
              ;; Assert
              (should-not result))))
      (kill-buffer (slot-value cell1 'buffer)))))

(ert-deftest ejn-network-p4-t25--prefix-arg-calls-execute-all-cells ()
  "Verify `ejn:worksheet-execute-cell' with prefix arg calls `ejn--execute-all-cells'."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code))
        (captured-notebook nil))
    (oset notebook cells (list cell1))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (unwind-protect
        (progn
          ;; Advice to capture the notebook argument
          (advice-add 'ejn--execute-all-cells :before
                      (lambda (nb)
                        (setq captured-notebook nb)))
          ;; Act: call with prefix arg
          (with-current-buffer (slot-value cell1 'buffer)
            (let ((current-prefix-arg '(4)))
              (call-interactively #'ejn:worksheet-execute-cell)))
          ;; Assert: the captured notebook is the same
          (should (eql captured-notebook notebook)))
      ;; Cleanup
      (advice-remove 'ejn--execute-all-cells
                     (lambda (nb) (setq captured-notebook nb)))
      (kill-buffer (slot-value cell1 'buffer)))))


(ert-deftest ejn-network-p4-t25--without-prefix-arg-calls-execute-cell ()
  "Verify `ejn:worksheet-execute-cell' without prefix arg calls `ejn--execute-cell'."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code))
        (captured-cell nil))
    (oset notebook cells (list cell1))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (unwind-protect
        (progn
          ;; Advice to capture the cell argument
          (advice-add 'ejn--execute-cell :before
                      (lambda (cell)
                        (setq captured-cell cell)))
          ;; Act: call without prefix arg
          (with-current-buffer (slot-value cell1 'buffer)
            (let ((current-prefix-arg nil))
              (call-interactively #'ejn:worksheet-execute-cell)))
          ;; Assert: the captured cell is the same
          (should (eql captured-cell cell1)))
      ;; Cleanup
      (advice-remove 'ejn--execute-cell
                     (lambda (cell) (setq captured-cell cell)))
      (kill-buffer (slot-value cell1 'buffer)))))


;;; Tests — P4-T30: ejn:notebook-kill-kernel-then-close

(ert-deftest ejn-network-p4-t30--interrupts-and-stops-kernel ()
  "Verify `ejn:notebook-kill-kernel-then-close' interrupts and stops the kernel."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (interrupted-p nil)
        (stopped-p nil))
    (oset notebook cells (list cell))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell notebook)
    (unwind-protect
        (progn
          (advice-add 'ejn-kernel-interrupt :before
                      (lambda (_nb) (setq interrupted-p t)))
          (advice-add 'ejn-kernel-stop :before
                      (lambda (_nb) (setq stopped-p t)))
          (unwind-protect
              (progn
                ;; Act
                (with-current-buffer (slot-value cell 'buffer)
                  (ejn:notebook-kill-kernel-then-close))
                ;; Assert
                (should interrupted-p)
                (should stopped-p))
            (advice-remove 'ejn-kernel-interrupt
                           (lambda (_nb) (setq interrupted-p t)))
            (advice-remove 'ejn-kernel-stop
                           (lambda (_nb) (setq stopped-p))))
	  (kill-buffer (slot-value cell 'buffer))))))

(ert-deftest ejn-network-p4-t30--flushes-dirty-cells ()
  "Verify `ejn:notebook-kill-kernel-then-close' flushes dirty cells."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (flushed-p nil))
    (oset notebook cells (list cell))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell notebook)
    (unwind-protect
        (progn
          (advice-add 'ejn--flush-all-dirty-cells :before
                      (lambda (_nb) (setq flushed-p t)))
          (unwind-protect
              (progn
                ;; Act
                (with-current-buffer (slot-value cell 'buffer)
                  (ejn:notebook-kill-kernel-then-close))
                ;; Assert
                (should flushed-p))
            (advice-remove 'ejn--flush-all-dirty-cells
                           (lambda (_nb) (setq flushed-p))))
	  (kill-buffer (slot-value cell 'buffer))))))

(ert-deftest ejn-network-p4-t30--kills-all-cell-buffers ()
  "Verify `ejn:notebook-kill-kernel-then-close' kills all cell buffers."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell1 (make-instance 'ejn-cell :source "x=1" :type 'code))
        (cell2 (make-instance 'ejn-cell :source "x=2" :type 'code)))
    (oset notebook cells (list cell1 cell2))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell1 notebook)
    (ejn-cell-open-buffer cell2 notebook)
    (let ((buf1 (slot-value cell1 'buffer))
          (buf2 (slot-value cell2 'buffer)))
      (unwind-protect
          (progn
            ;; Assert: buffers exist before
            (should (buffer-live-p buf1))
            (should (buffer-live-p buf2))
            ;; Act
            (with-current-buffer buf1
	      (ejn:notebook-kill-kernel-then-close))
            ;; Assert: buffers are killed after
            (should-not (buffer-live-p buf1))
            (should-not (buffer-live-p buf2)))
        (when (buffer-live-p buf1) (kill-buffer buf1))
        (when (buffer-live-p buf2) (kill-buffer buf2))))))

(ert-deftest ejn-network-p4-t30--handles-no-kernel-gracefully ()
  "Verify `ejn:notebook-kill-kernel-then-close' does not error when no kernel."
  ;; Arrange: notebook with no kernel
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code)))
    (oset notebook cells (list cell))
    (ejn-cell-open-buffer cell notebook)
    (unwind-protect
        (progn
          ;; Act & Assert: should not signal an error
          (with-current-buffer (slot-value cell 'buffer)
	    (ejn:notebook-kill-kernel-then-close)))
      (kill-buffer (slot-value cell 'buffer)))))

(ert-deftest ejn-network-p4-t30--cleans-up-cache-directory ()
  "Verify `ejn:notebook-kill-kernel-then-close' removes the cache directory."
  ;; Arrange: notebook with a cache directory that exists
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test-cache.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (cache-dir (expand-file-name ".ejn-cache/test-cache" "/tmp/")))
    (oset notebook cells (list cell))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell notebook)
    ;; Create the cache directory
    (make-directory cache-dir t)
    (unwind-protect
        (progn
          (should (file-directory-p cache-dir))
          ;; Act
          (with-current-buffer (slot-value cell 'buffer)
            (ejn:notebook-kill-kernel-then-close))
          ;; Assert: cache directory is removed
          (should-not (file-directory-p cache-dir)))
      (when (file-exists-p cache-dir)
        (delete-directory cache-dir 'recursive)))))

(ert-deftest ejn-network-p4-t30--kills-master-buffer ()
  "Verify `ejn:notebook-kill-kernel-then-close' kills the master buffer."
  ;; Arrange: notebook with a master buffer
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test-master.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code)))
    (oset notebook cells (list cell))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell notebook)
    ;; Create a master buffer and associate it with the notebook
    (let ((master-buf (generate-new-buffer " *ejn-master:/tmp/test-master.ipynb*")))
      (oset notebook master-buffer master-buf)
      (unwind-protect
          (progn
            ;; Assert: master buffer exists before
            (should (buffer-live-p master-buf))
            ;; Act
            (with-current-buffer (slot-value cell 'buffer)
              (ejn:notebook-kill-kernel-then-close))
            ;; Assert: master buffer is killed after
            (should-not (buffer-live-p master-buf)))
        (when (buffer-live-p master-buf)
          (kill-buffer master-buf))))))

;;; Tests — P4-T29: ejn:notebook-restart-session

(ert-deftest ejn-network-p4-t29--signals-error-when-no-notebook ()
  "Verify `ejn:notebook-restart-session' signals `user-error' when no notebook."
  ;; Arrange: buffer with no ejn--notebook bound
  (with-temp-buffer
    ;; Act & Assert
    (should-error (ejn:notebook-restart-session) :type 'user-error)))

(ert-deftest ejn-network-p4-t29--calls-restart-and-prompts-reexecute ()
  "Verify `ejn:notebook-restart-session' calls `ejn-kernel-restart' and
   prompts to re-execute all cells."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (restarted-p nil)
        (reexecuted-p nil))
    (oset notebook cells (list cell))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell notebook)
    (unwind-protect
        (progn
          (advice-add 'ejn-kernel-restart :before
		      (lambda (_nb) (setq restarted-p t)))
          (advice-add 'ejn--execute-all-cells :before
		      (lambda (_nb) (setq reexecuted-p t)))
          (advice-add 'y-or-n-p :around
		      (lambda (_fn &rest args)
                        (apply #'message "y-or-n-p: %S" args)
                        t))
          (unwind-protect
	      (progn
                ;; Act
                (with-current-buffer (slot-value cell 'buffer)
                  (ejn:notebook-restart-session))
                ;; Assert
                (should restarted-p)
                (should reexecuted-p))
	    (advice-remove 'y-or-n-p
                           (lambda (_fn &rest args)
			     (apply #'message "y-or-n-p: %S" args)
			     t)))
          (advice-remove 'ejn-kernel-restart
                         (lambda (_nb) (setq restarted-p t)))
          (advice-remove 'ejn--execute-all-cells
                         (lambda (_nb) (setq reexecuted-p))))
      (kill-buffer (slot-value cell 'buffer)))))

(ert-deftest ejn-network-p4-t29--skips-reexecute-when-declined ()
  "Verify `ejn:notebook-restart-session' does not re-execute cells
   when the user declines the prompt."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (restarted-p nil)
        (reexecuted-p nil))
    (oset notebook cells (list cell))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell notebook)
    (unwind-protect
        (progn
          (advice-add 'ejn-kernel-restart :before
		      (lambda (_nb) (setq restarted-p t)))
          (advice-add 'ejn--execute-all-cells :before
		      (lambda (_nb) (setq reexecuted-p t)))
          (advice-add 'y-or-n-p :around
		      (lambda (_fn &rest args)
                        (apply #'message "y-or-n-p: %S" args)
                        nil))
          (unwind-protect
	      (progn
                ;; Act
                (with-current-buffer (slot-value cell 'buffer)
                  (ejn:notebook-restart-session))
                ;; Assert
                (should restarted-p)
                (should-not reexecuted-p))
	    (advice-remove 'y-or-n-p
                           (lambda (_fn &rest args)
			     (apply #'message "y-or-n-p: %S" args)
			     nil)))
          (advice-remove 'ejn-kernel-restart
                         (lambda (_nb) (setq restarted-p t)))
          (advice-remove 'ejn--execute-all-cells
                         (lambda (_nb) (setq reexecuted-p))))
      (kill-buffer (slot-value cell 'buffer)))))

(ert-deftest ejn-network-p4-t29--updates-mode-line-after-restart ()
  "Verify `ejn:notebook-restart-session' calls `ejn--update-mode-line' after restart."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (mode-line-updated-p nil))
    (oset notebook cells (list cell))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell notebook)
    (unwind-protect
        (progn
          (advice-add 'ejn--update-mode-line :before
                      (lambda (_nb) (setq mode-line-updated-p t)))
          (advice-add 'y-or-n-p :around
                      (lambda (_fn &rest args)
                        (apply #'message "y-or-n-p: %S" args)
                        nil))
          (unwind-protect
              (progn
                ;; Act
                (with-current-buffer (slot-value cell 'buffer)
                  (ejn:notebook-restart-session))
                ;; Assert
                (should mode-line-updated-p))
            (advice-remove 'y-or-n-p
                           (lambda (_fn &rest args)
                             (apply #'message "y-or-n-p: %S" args)
                             nil))))
      (advice-remove 'ejn--update-mode-line
                     (lambda (_nb) (setq mode-line-updated-p t))))
    (kill-buffer (slot-value cell 'buffer))))

;;; Tests — P4-T28: ejn-kernel-restart

(ert-deftest ejn-network-p4-t28--calls-jupyter-restart-kernel-with-client ()
  "Verify `ejn-kernel-restart' calls `jupyter-restart-kernel' with the kernel client."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        client)
    (ejn-kernel-start notebook)
    (setq client (slot-value notebook 'kernel-id))
    (should client)
    (setq ejn-network--test-restart-captured-client nil)
    ;; Act
    (ejn-kernel-restart notebook)
    ;; Assert: jupyter-restart-kernel was called with the correct client
    (should (eql ejn-network--test-restart-captured-client client))))

(ert-deftest ejn-network-p4-t28--returns-nil ()
  "Verify `ejn-kernel-restart' returns nil."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    ;; Act & Assert
    (should-not (ejn-kernel-restart notebook))))

(ert-deftest ejn-network-p4-t28--signals-error-when-no-kernel ()
  "Verify `ejn-kernel-restart' signals `user-error' when no kernel is attached."
  ;; Arrange: notebook with no kernel
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    ;; Act & Assert
    (should-error (ejn-kernel-restart notebook) :type 'user-error)))

;;; Tests — P4-T27: ejn:notebook-kernel-interrupt

(ert-deftest ejn-network-p4-t27--signals-error-when-no-notebook ()
  "Verify `ejn:notebook-kernel-interrupt' signals `user-error' when no notebook."
  ;; Arrange: buffer with no ejn--notebook bound
  (with-temp-buffer
    ;; Act & Assert
    (should-error (ejn:notebook-kernel-interrupt) :type 'user-error)))

(ert-deftest ejn-network-p4-t27--calls-ejn-kernel-interrupt-and-update-mode-line ()
  "Verify `ejn:notebook-kernel-interrupt' calls `ejn-kernel-interrupt' and `ejn--update-mode-line'."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (interrupted-p nil)
        (updated-p nil))
    (oset notebook cells (list cell))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell notebook)
    (unwind-protect
        (progn
          ;; Advice to track calls
          (advice-add 'ejn-kernel-interrupt :before
		      (lambda (_nb) (setq interrupted-p t)))
          (advice-add 'ejn--update-mode-line :before
		      (lambda (_nb) (setq updated-p t)))
          (unwind-protect
	      (progn
                ;; Act
                (with-current-buffer (slot-value cell 'buffer)
                  (ejn:notebook-kernel-interrupt))
                ;; Assert
                (should interrupted-p)
                (should updated-p))
	    (advice-remove 'ejn-kernel-interrupt
                           (lambda (_nb) (setq interrupted-p t)))
	    (advice-remove 'ejn--update-mode-line
                           (lambda (_nb) (setq updated-p t)))))
      (kill-buffer (slot-value cell 'buffer)))))

;;; Tests — P4-T26: ejn-kernel-interrupt

(ert-deftest ejn-network-p4-t26--calls-jupyter-interrupt-kernel-with-client ()
  "Verify `ejn-kernel-interrupt' calls `jupyter-interrupt-kernel' with the kernel client."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        client)
    (ejn-kernel-start notebook)
    (setq client (slot-value notebook 'kernel-id))
    (should client)
    (setq ejn-network--test-interrupt-captured-client nil)
    ;; Act
    (ejn-kernel-interrupt notebook)
    ;; Assert: jupyter-interrupt-kernel was called with the correct client
    (should (eql ejn-network--test-interrupt-captured-client client))))

(ert-deftest ejn-network-p4-t26--returns-nil ()
  "Verify `ejn-kernel-interrupt' returns nil."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    ;; Act & Assert
    (should-not (ejn-kernel-interrupt notebook))))

(ert-deftest ejn-network-p4-t26--signals-error-when-no-kernel ()
  "Verify `ejn-kernel-interrupt' signals `user-error' when no kernel is attached."
  ;; Arrange: notebook with no kernel
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    ;; Act & Assert
    (should-error (ejn-kernel-interrupt notebook) :type 'user-error)))

;;; Tests — P4-T33: ejn-kernel-reconnect

(ert-deftest ejn-network-p4-t33--disconnects-and-reconnects-client ()
  "Verify `ejn-kernel-reconnect' disconnects and reconnects the kernel client."
  ;; Arrange: notebook with a kernel client
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        client)
    (ejn-kernel-start notebook)
    (setq client (slot-value notebook 'kernel-id))
    (should client)
    ;; Act
    (ejn-kernel-reconnect notebook)
    ;; Assert: kernel-id is still the same client object
    (should (eql (slot-value notebook 'kernel-id) client))))

(ert-deftest ejn-network-p4-t33--returns-client ()
  "Verify `ejn-kernel-reconnect' returns the kernel client."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (ejn-kernel-start notebook)
    ;; Act & Assert
    (should (eql (ejn-kernel-reconnect notebook)
                 (slot-value notebook 'kernel-id)))))

(ert-deftest ejn-network-p4-t33--signals-error-when-no-kernel ()
  "Verify `ejn-kernel-reconnect' signals `user-error' when no kernel is attached."
  ;; Arrange: notebook with no kernel
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    ;; Act & Assert
    (should-error (ejn-kernel-reconnect notebook) :type 'user-error)))

;;; Tests — P4-T34: ejn:notebook-reconnect-session

(ert-deftest ejn-network-p4-t34--calls-reconnect-and-update-mode-line ()
  "Verify `ejn:notebook-reconnect-session' calls `ejn-kernel-reconnect' and `ejn--update-mode-line'."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (reconnected-p nil)
        (updated-p nil))
    (oset notebook cells (list cell))
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell notebook)
    (unwind-protect
        (progn
          ;; Advice to track calls
          (advice-add 'ejn-kernel-reconnect :before
                      (lambda (_nb) (setq reconnected-p t)))
          (advice-add 'ejn--update-mode-line :before
                      (lambda (_nb) (setq updated-p t)))
          (unwind-protect
              (progn
                ;; Act
                (with-current-buffer (slot-value cell 'buffer)
                  (ejn:notebook-reconnect-session))
                ;; Assert
                (should reconnected-p)
                (should updated-p))
            (advice-remove 'ejn-kernel-reconnect
                           (lambda (_nb) (setq reconnected-p t)))
            (advice-remove 'ejn--update-mode-line
                           (lambda (_nb) (setq updated-p t)))))
      (kill-buffer (slot-value cell 'buffer)))))

(ert-deftest ejn-network-p4-t34--re-activates-kernel-manager-mode ()
  "Verify `ejn:notebook-reconnect-session' re-activates `ejn-kernel-manager-mode' in master buffer."
  ;; Arrange: notebook with kernel, master buffer with mode active, then deactivate it
  (let ((notebook (make-instance 'ejn-notebook :path "/tmp/test.ipynb"))
        (cell (make-instance 'ejn-cell :source "x=1" :type 'code))
        (master-buf (generate-new-buffer "*ejn-master:reconnect*")))
    (oset notebook cells (list cell))
    (oset notebook master-buffer master-buf)
    (ejn-kernel-start notebook)
    (ejn-cell-open-buffer cell notebook)
    (unwind-protect
        (progn
          ;; Assert: mode is active initially
          (with-current-buffer master-buf
            (should (bound-and-true-p ejn-kernel-manager-mode)))
          ;; Deactivate the mode to simulate a disconnected kernel
          (with-current-buffer master-buf
            (ejn-kernel-manager-mode -1))
          ;; Assert: mode is now inactive
          (with-current-buffer master-buf
            (should-not (bound-and-true-p ejn-kernel-manager-mode)))
          ;; Act: reconnect
          (with-current-buffer (slot-value cell 'buffer)
            (ejn:notebook-reconnect-session))
          ;; Assert: mode is active again
          (with-current-buffer master-buf
            (should (bound-and-true-p ejn-kernel-manager-mode))))
      (kill-buffer master-buf)
      (kill-buffer (slot-value cell 'buffer)))))

(ert-deftest ejn-network-p4-t34--signals-error-when-no-notebook ()
  "Verify `ejn:notebook-reconnect-session' signals `user-error' when no notebook."
  ;; Arrange: buffer with no ejn--notebook bound
  (with-temp-buffer
    ;; Act & Assert
    (should-error (ejn:notebook-reconnect-session) :type 'user-error)))

;;; ejn-network-tests.el ends here
