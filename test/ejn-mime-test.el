;;; ejn-mime-test.el --- Tests for ejn-mime  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-mime)

;;; Code:

(ert-deftest ejn-mime-test/registry-is-hash-table ()
  "Registry should be a hash table."
  (should (hash-table-p ejn-mime-registry)))

(ert-deftest ejn-mime-test/register-and-lookup-handler ()
  "Registering a handler should make it findable."
  (ejn-register-mime-handler "test/type" (lambda (_data) nil) :priority 5)
  (should (functionp (ejn-mime-handler-for "test/type"))))

(ert-deftest ejn-mime-test/unregistered-type-returns-nil ()
  "Looking up an unregistered MIME type should return nil."
  (should-not (ejn-mime-handler-for "nonexistent/type")))

(ert-deftest ejn-mime-test/higher-priority-overrides ()
  "Registering with higher priority should replace the handler."
  (ejn-register-mime-handler "test/override" (lambda (_) 'low) :priority 5)
  (ejn-register-mime-handler "test/override" (lambda (_) 'high) :priority 20)
  (should (eq 'high (funcall (ejn-mime-handler-for "test/override") nil))))

(ert-deftest ejn-mime-test/plain-text-handler-registered ()
  "Text/plain handler should be auto-registered."
  (should (functionp (ejn-mime-handler-for "text/plain"))))

(ert-deftest ejn-mime-test/plain-text-handler-returns-string ()
  "Plain text handler should return the text data as a string."
  (let ((handler (ejn-mime-handler-for "text/plain"))
        (data '("hello" " " "world")))
    (should (string= "hello world" (funcall handler data)))))

(ert-deftest ejn-mime-test/markdown-handler-registered ()
  "Text/markdown handler should be auto-registered."
  (should (functionp (ejn-mime-handler-for "text/markdown"))))

(ert-deftest ejn-mime-test/markdown-handler-returns-string ()
  "Markdown handler should return concatenated markdown text."
  (let ((handler (ejn-mime-handler-for "text/markdown"))
        (data '("# Heading" "\n" "Body")))
    (should (string= "# Heading\nBody" (funcall handler data)))))

(ert-deftest ejn-mime-test/png-handler-registered ()
  "Image/png handler should be auto-registered."
  (should (functionp (ejn-mime-handler-for "image/png"))))

(ert-deftest ejn-mime-test/png-handler-returns-image ()
  "PNG handler should return an Emacs image object."
  (let* ((handler (ejn-mime-handler-for "image/png"))
         (data '("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="))
         (result (funcall handler data)))
    (should (imagep result))))

(ert-deftest ejn-mime-test/svg-handler-registered ()
  "Image/svg+xml handler should be auto-registered."
  (should (functionp (ejn-mime-handler-for "image/svg+xml"))))

(ert-deftest ejn-mime-test/svg-handler-returns-image ()
  "SVG handler should return an Emacs image object."
  (let* ((handler (ejn-mime-handler-for "image/svg+xml"))
         (data '("<svg xmlns='http://www.w3.org/2000/svg' width='10' height='10'/>"))
         (result (funcall handler data)))
    (should (imagep result))))

(provide 'ejn-mime-test)
;;; ejn-mime-test.el ends here
