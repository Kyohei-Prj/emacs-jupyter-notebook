### Directory Structure

Create the canonical directory layout for an Eask-based Emacs package:

```
emacs-jupyter-notebook/
│── ejn.el
├── lisp/
│   ├── ejn-cell.el
│   ├── ejn-core.el
│   ├── ejn-lsp.el
│   ├── ejn-master.el
│   ├── ejn-network.el
│   ├── ejn-notebook.el
│   └── ejn-ui.el
├── test/
│   ├── ejn-test.el
│   ├── ejn-cell-test.el
│   ├── ejn-core-test.el
│   ├── ejn-lsp-test.el
│   ├── ejn-master-test.el
│   ├── ejn-network-test.el
│   ├── ejn-notebook-test.el
│   └── ejn-ui-test.el
├── .ejn-cache/          ← gitignored; holds shadow files at runtime
├── Eask
├── Makefile
└── README.md
```

### Tips
- Use `Makefile` for testing and linting.
- Whenever you encounter any errors, it is most likely unbalanced parenthesis. Use appropriate `skills` or `mcp` to handle it effeciently.
- Use `elisp-dev` to refer to Emacs Lisp (elisp) document.
- Write one function/code block at a time. Do not write all at once.
- Official `jupyter.el` repository is cloned under `/home/kyohei/Projects/jupyter` as a reference.

## TDD Lessons

<!-- Each entry is appended by the tdd-lessons skill. Newest entries go at the top. -->

---

### P5-T2 Emacs `let` bindings not visible to sibling bindings

**Date:** 2026-05-05
**Task:** Fix `ejn--cell-to-json` and `ejn--notebook-to-json` to emit all required nbformat 4.5 fields.

**Struggle:**
Three tests failed with `(void-variable cell-json)` and `(void-variable nb-json)` despite correct-looking `let` forms like:
```elisp
(let ((cell-json (ejn--cell-to-json cell))
      (metadata (gethash "metadata" cell-json)))
  ...)
```
The error occurred during evaluation of the second binding — `cell-json` was unbound when `(gethash "metadata" cell-json)` ran.

**Root cause:**
In Emacs Lisp, `let` bindings are NOT visible to subsequent bindings in the same `let` clause. All bindings are evaluated in the scope that existed before the `let`. This differs from `let*` where each binding is visible to subsequent ones. The pattern `(let ((a (expr1)) (b (uses-a a))) ...)` is a `void-variable` error in `let`, but works in `let*`.

**Resolution:**
Restructured the tests to bind the primary variable first, then perform dependent operations in the `let` body:
```elisp
;; WRONG — cell-json void in second binding
(let ((cell-json (ejn--cell-to-json cell))
      (metadata (gethash "metadata" cell-json)))
  (should (hash-table-p metadata)))

;; CORRECT — gethash runs in body where cell-json is bound
(let ((cell-json (ejn--cell-to-json cell)))
  (should (hash-table-p (gethash "metadata" cell-json))))
```
Alternatively, use `let*` if you need binding visibility.

**Pattern:** `elisp-let-binding-scope`
In Emacs elisp `let`, bindings are NOT visible to sibling bindings in the same clause — use `let*` for sequential binding visibility, or move dependent expressions into the body.

---
