### Directory Structure

Create the canonical directory layout for an Eask-based Emacs package:

```
ejn/
│── ejn.el
├── lisp/
│   ├── ejn-core.el
│   ├── ejn-network.el
│   └── ejn-lsp.el
├── test/
│   └── ejn-test.el
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
