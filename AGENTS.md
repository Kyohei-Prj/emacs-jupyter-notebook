### Directory Structure

Create the canonical directory layout for an Eask-based Emacs package:

```
emacs-jupyter-notebook/
│── ejn.el
├── lisp/
│   ├── ejn-core.el
│   ...
│
├── test/
│   ├── ejn-core-test.el
│   ...
│
├── docs/
│   ├── architecture
│   ├── adr
│   └── diagrams
│
├── Eask
├── Makefile
└── README.md
```

### Tips
- Use `Makefile` for testing and linting.
- Whenever you encounter any errors, it is most likely unbalanced parenthesis. Use appropriate `skills` or `mcp` to handle it effeciently.
- Use `elisp-dev` to refer to Emacs Lisp (elisp) document.
- Write one function/code block at a time. Do not write all at once.
- Official `emacs-jupyter` repository is cloned under `/home/kyohei/Projects/jupyter` as a reference.
- Official `code-cell.el` repository is cloned under `/home/kyohei/Project/code-cells.el/` as a reference.
- Official `emacs-jupyter-notebook (ein)` repository is cloned under `/home/kyohei/Project/emacs-ipython-notebook/` as a reference.acs

## TDD Lessons

<!-- Each entry is appended by the tdd-lessons skill. Newest entries go at the top. -->

---
