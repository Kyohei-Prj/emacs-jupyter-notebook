;;; ejn-ui-test.el --- ERT tests for ejn-ui (undo, visuals)  -*- lexical-binding: t; -*-

(require 'ert)

(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory
                                (or load-file-name buffer-file-name))))
(require 'ejn-core)
(require 'ejn-cell)
(require 'ejn-ui)


;; ===== P8-T1: ejn--undo-before-change snapshot capture =====

(ert-deftest ejn-ui-test-p8-t1--before-change-captures-full-buffer ()
  "ejn--undo-before-change captures full buffer content into
`ejn--pre-change-snapshot'."
  (with-temp-buffer
    (insert "initial buffer content")
    (ejn--undo-before-change (point-min) (point-max))
    (should (string= "initial buffer content"
                     ejn--pre-change-snapshot))))

;; ===== P8-T1: ejn--undo-after-change uses snapshot for before-text =====

(ert-deftest ejn-ui-test-p8-t1--after-change-uses-snapshot-for-before-text ()
  "ejn--undo-after-change uses `ejn--pre-change-snapshot' as the
before-text in the undo record, and clears the snapshot afterward."
  (with-temp-buffer
    (insert "hello")
    ;; Set up a notebook and cell so the hook has context
    (let* ((notebook (make-instance 'ejn-notebook))
           (cell (make-instance 'ejn-cell :type 'code :source "hello")))
      (oset notebook cells (list cell))
      (set (make-local-variable 'ejn--notebook) notebook)
      (set (make-local-variable 'ejn--cell) cell)
      ;; Simulate before-change hook capturing snapshot
      (setq ejn--pre-change-snapshot "hello")
      ;; Simulate user typing: buffer is now "hello world"
      (insert " world")
      ;; Call after-change with the region that was replaced
      (ejn--undo-after-change 6 6 0)
      ;; The snapshot should be cleared
      (should-not ejn--pre-change-snapshot)
      ;; The undo record should have the snapshot as :before
      (let* ((undo-stack (slot-value notebook 'undo-stack))
             (record (car undo-stack)))
        (should (= (length undo-stack) 1))
        (should (string= "hello" (ejn-undo-record-before record)))
        (should (string= "hello world" (ejn-undo-record-after record)))))))

(ert-deftest ejn-ui-test-p8-t1--after-change-falls-back-when-no-snapshot ()
  "ejn--undo-after-change falls back to empty string when
`ejn--pre-change-snapshot' is nil (e.g., first edit after buffer open)."
  (with-temp-buffer
    (insert "first")
    (let* ((notebook (make-instance 'ejn-notebook))
           (cell (make-instance 'ejn-cell :type 'code :source "first")))
      (oset notebook cells (list cell))
      (set (make-local-variable 'ejn--notebook) notebook)
      (set (make-local-variable 'ejn--cell) cell)
      ;; No snapshot set (simulating missing before-change hook)
      (setq ejn--pre-change-snapshot nil)
      (ejn--undo-after-change 1 6 5)
      (let ((record (car (slot-value notebook 'undo-stack))))
        (should (string= "" (ejn-undo-record-before record)))))))


;; ===== P8-T1: Hook registration in ejn-cell-open-buffer =====

(ert-deftest ejn-cell-test-p8-t1--open-buffer-registers-before-change-hook ()
  "ejn-cell-open-buffer registers `ejn--undo-before-change' on
`before-change-functions' (locally)."
  (let* ((tmp (make-temp-file "ejn-p8t1-" nil ".ipynb"
                              "{\"nbformat\":4,\"nbformat_minor\":5,\"metadata\":{},\"cells\":[]}"))
         (notebook (ejn-notebook-load tmp)))
    (unwind-protect
        (let ((cell (make-instance 'ejn-cell :type 'code :source "test")))
          (oset notebook cells (list cell))
          (let ((buf (ejn-cell-open-buffer cell notebook)))
            (with-current-buffer buf
              (should (memq #'ejn--undo-before-change
                            before-change-functions)))))
      (delete-file tmp)
      (dolist (buf (buffer-list))
        (when (string-prefix-p "*ejn-" (buffer-name buf))
          (kill-buffer buf))))))


;; ===== P8-T2: ejn-global-undo content restore without erase-buffer =====

(ert-deftest ejn-ui-test-p8-t2--undo-restore-content-without-erase-buffer ()
  "ejn-global-undo restores the buffer content and cell source
for a :content undo record, using replace-buffer-contents
without erase-buffer."
  (let* ((notebook (make-instance 'ejn-notebook))
         (cell (make-instance 'ejn-cell :type 'code :source "original text"))
         (buf (generate-new-buffer "*ejn-test-undo-content*")))
    (unwind-protect
        (progn
          (oset notebook cells (list cell))
          (oset cell buffer buf)
          ;; Push a content undo record onto the stack
          (push (make-ejn-undo-record
                 :cell-id (slot-value cell 'id)
                 :before "original text"
                 :after "edited text"
                 :timestamp (float-time)
                 :operation :content)
                (slot-value notebook 'undo-stack))
          ;; Set up the cell buffer with edited content and notebook var
          (with-current-buffer buf
            (insert "edited text")
            (set (make-local-variable 'ejn--notebook) notebook)
            ;; Call ejn-global-undo from the cell buffer
            (ejn-global-undo))
          ;; Assert: buffer content restored to before-text
          (with-current-buffer buf
            (should (string= "original text"
                             (buffer-substring-no-properties
                              (point-min) (point-max)))))
          ;; Assert: cell source slot restored
          (should (string= "original text" (slot-value cell 'source)))
          ;; Assert: undo stack is empty after one pop
          (should (= 0 (length (slot-value notebook 'undo-stack)))))
      (when (buffer-live-p buf)
        (kill-buffer buf)))))


;; ===== P8-T2: ejn-global-undo structural dispatch =====

(ert-deftest ejn-ui-test-p8-t2--undo-dispatches-structural-insert ()
  "ejn-global-undo dispatches a structural :insert record to
ejn--undo-structural-change, reversing the cell insertion."
  (let* ((notebook (make-instance 'ejn-notebook))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (buf (generate-new-buffer "*ejn-test-undo-struct*")))
    (unwind-protect
        (progn
          (oset notebook cells (list cell-a cell-b))
          (push (make-ejn-undo-record
                 :cell-id "structural"
                 :before (list (slot-value cell-a 'id))
                 :after (list (slot-value cell-a 'id)
                              (slot-value cell-b 'id))
                 :timestamp (float-time)
                 :operation :insert
                 :notebook notebook
                 :data (list cell-b 1))
                (slot-value notebook 'undo-stack))
          ;; Set up notebook var in current buffer (not a cell buffer)
          (with-current-buffer buf
            (set (make-local-variable 'ejn--notebook) notebook)
            (should (= 2 (length (slot-value notebook 'cells))))
            (ejn-global-undo))
          ;; Assert: cell B removed from the notebook by undo
          (should (= 1 (length (slot-value notebook 'cells))))
          (should (eq cell-a (car (slot-value notebook 'cells))))
          ;; Assert: undo stack is empty
          (should (= 0 (length (slot-value notebook 'undo-stack)))))
      (when (buffer-live-p buf)
        (kill-buffer buf)))))


;; ===== P8-T2: Content undo must not use erase-buffer (B41) =====

(ert-deftest ejn-ui-test-p8-t2--undo-content-preserves-markers ()
  "ejn-global-undo content restore preserves markers in the cell
buffer, proving that erase-buffer is not called (B41).

erase-buffer destroys all markers and text properties. Using
replace-buffer-contents from a temp buffer preserves them."
  (let* ((notebook (make-instance 'ejn-notebook))
         (cell (make-instance 'ejn-cell :type 'code :source "original text here"))
         (buf (generate-new-buffer "*ejn-test-undo-markers*"))
         (test-marker nil))
    (unwind-protect
        (progn
          (oset notebook cells (list cell))
          (oset cell buffer buf)
          ;; Push a content undo record onto the stack
          (push (make-ejn-undo-record
                 :cell-id (slot-value cell 'id)
                 :before "original text here"
                 :after "edited text here"
                 :timestamp (float-time)
                 :operation :content)
                (slot-value notebook 'undo-stack))
          ;; Set up the cell buffer with edited content and a marker
          (with-current-buffer buf
            (insert "edited text here")
            ;; Place a marker and capture it in lexical scope
            (setq test-marker (copy-marker (+ (point-min) 4) t))
            ;; Set a text property on a region
            (put-text-property (point-min)
                               (+ (point-min) 6)
                               'undo-test-prop 'preserved)
            (set (make-local-variable 'ejn--notebook) notebook)
            ;; Call ejn-global-undo from the cell buffer
            (ejn-global-undo))
          ;; Assert: buffer content restored to before-text
          (with-current-buffer buf
            (should (string= "original text here"
                             (buffer-substring-no-properties
                              (point-min) (point-max)))))
          ;; Assert: marker survives and still points to buf
          ;; (erase-buffer destroys all markers; replace-buffer-contents preserves them)
          (should (eq buf (marker-buffer test-marker)))
          ;; Assert: undo stack is empty
          (should (= 0 (length (slot-value notebook 'undo-stack)))))
      (when (buffer-live-p buf)
        (kill-buffer buf)))))


;; ===== P8-T2: Structural undo dispatches polymode refresh (B42) =====

(ert-deftest ejn-ui-test-p8-t2--undo-structural-refreshes-polymode ()
  "ejn-global-undo calls ejn--poly-refresh-cells on the master
buffer after dispatching a structural undo record (B42)."
  (let* ((notebook (make-instance 'ejn-notebook))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (master-buf (generate-new-buffer "*ejn-master-test*"))
         (buf (generate-new-buffer "*ejn-test-undo-poly*"))
         (refresh-called nil))
    (unwind-protect
        (progn
          (oset notebook cells (list cell-a cell-b))
          (oset notebook master-buffer master-buf)
          (push (make-ejn-undo-record
                 :cell-id "structural"
                 :before (list (slot-value cell-a 'id))
                 :after (list (slot-value cell-a 'id)
                              (slot-value cell-b 'id))
                 :timestamp (float-time)
                 :operation :insert
                 :notebook notebook)
                (slot-value notebook 'undo-stack))
          ;; Stub ejn--poly-refresh-cells to track calls
          (fset 'ejn--poly-refresh-cells
                (lambda ()
                  (setq refresh-called t)))
          (with-current-buffer buf
            (set (make-local-variable 'ejn--notebook) notebook)
            (ejn-global-undo))
          ;; Assert: polymode refresh was called
          (should refresh-called)
          ;; Assert: cell B was removed
          (should (= 1 (length (slot-value notebook 'cells))))
          (should (= 0 (length (slot-value notebook 'undo-stack))))
          ;; Clean up stub
          (fmakunbound 'ejn--poly-refresh-cells))
      (when (buffer-live-p master-buf)
        (kill-buffer master-buf))
      (when (buffer-live-p buf)
        (kill-buffer buf))
      ;; Ensure cleanup of stub even on test failure
      (when (fboundp 'ejn--poly-refresh-cells)
        (fmakunbound 'ejn--poly-refresh-cells)))))


;; ===== P8-T3: with-current-buffer nesting in cell type commands (B43, B44) =====

(ert-deftest ejn-ui-test-p8-t3--toggle-cell-type-preserves-current-buffer ()
  "ejn:worksheet-toggle-cell-type closes with-current-buffer before
markdown render and header refresh, so the caller's buffer is preserved (B43)."
  (let* ((notebook (make-instance 'ejn-notebook))
         (cell (make-instance 'ejn-cell :type 'code :source "test"))
         (cell-buf (generate-new-buffer "*ejn-test-cell*"))
         (caller-buf (generate-new-buffer "*ejn-test-caller*"))
         (master-buf (generate-new-buffer "*ejn-master-test*")))
    (unwind-protect
        (progn
          (oset notebook cells (list cell))
          (oset notebook master-buffer master-buf)
          (oset cell buffer cell-buf)
          ;; Stub dependent functions to avoid side effects
          (fset 'ejn-markdown-render-cell (lambda (_) nil))
          (fset 'ejn-cell-refresh-header (lambda (_) nil))
          (fset 'ejn--poly-refresh-cells (lambda () nil))
          (with-current-buffer caller-buf
            (set (make-local-variable 'ejn--cell) cell)
            (set (make-local-variable 'ejn--notebook) notebook)
            ;; Call toggle from the caller buffer
            (ejn:worksheet-toggle-cell-type)
            ;; Assert: we're still in the caller buffer, NOT the cell buffer
            (should (eq (current-buffer) caller-buf))))
      (when (buffer-live-p cell-buf)
        (kill-buffer cell-buf))
      (when (buffer-live-p caller-buf)
        (kill-buffer caller-buf))
      (when (buffer-live-p master-buf)
        (kill-buffer master-buf))
      (when (fboundp 'ejn-markdown-render-cell)
        (fmakunbound 'ejn-markdown-render-cell))
      (when (fboundp 'ejn-cell-refresh-header)
        (fmakunbound 'ejn-cell-refresh-header))
      (when (fboundp 'ejn--poly-refresh-cells)
        (fmakunbound 'ejn--poly-refresh-cells)))))

(ert-deftest ejn-ui-test-p8-t3--change-cell-type-preserves-current-buffer ()
  "ejn:worksheet-change-cell-type closes with-current-buffer before
markdown render and header refresh, so the caller's buffer is preserved (B44)."
  (let* ((notebook (make-instance 'ejn-notebook))
         (cell (make-instance 'ejn-cell :type 'code :source "test"))
         (cell-buf (generate-new-buffer "*ejn-test-cell2*"))
         (caller-buf (generate-new-buffer "*ejn-test-caller2*"))
         (master-buf (generate-new-buffer "*ejn-master-test2*")))
    (unwind-protect
        (progn
          (oset notebook cells (list cell))
          (oset notebook master-buffer master-buf)
          (oset cell buffer cell-buf)
          ;; Stub dependent functions
          (fset 'ejn-markdown-render-cell (lambda (_) nil))
          (fset 'ejn-cell-refresh-header (lambda (_) nil))
          (fset 'ejn--poly-refresh-cells (lambda () nil))
          ;; Mock completing-read to return "markdown" without user interaction
          (fset 'completing-read (lambda (&rest _) "markdown"))
          (with-current-buffer caller-buf
            (set (make-local-variable 'ejn--cell) cell)
            (set (make-local-variable 'ejn--notebook) notebook)
            ;; Call change-cell-type from the caller buffer
            (ejn:worksheet-change-cell-type)
            ;; Assert: we're still in the caller buffer, NOT the cell buffer
            (should (eq (current-buffer) caller-buf)))
          ;; Clean up mock
          (fmakunbound 'completing-read))
      (when (buffer-live-p cell-buf)
        (kill-buffer cell-buf))
      (when (buffer-live-p caller-buf)
        (kill-buffer caller-buf))
      (when (buffer-live-p master-buf)
        (kill-buffer master-buf))
      (when (fboundp 'ejn-markdown-render-cell)
        (fmakunbound 'ejn-markdown-render-cell))
      (when (fboundp 'ejn-cell-refresh-header)
        (fmakunbound 'ejn-cell-refresh-header))
      (when (fboundp 'ejn--poly-refresh-cells)
        (fmakunbound 'ejn--poly-refresh-cells))
      (when (fboundp 'completing-read)
        ;; Only unbound if we set it; it's a primitive so this is safe in tests
        (when (equal (symbol-function 'completing-read)
                     (lambda (&rest _) "markdown"))
          (fmakunbound 'completing-read))))))

;;; ejn-ui-test.el ends here
