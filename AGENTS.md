### Directory Structure

Current directory layout:

```
emacs-jupyter-notebook/
├── ejn.el                  # Package entry point
├── Eask                    # Eask build configuration
├── Makefile                # Build, lint, and test targets
├── README.md
│
├── lisp/                   # Core source modules
│   ├── ejn-core.el
│   ├── ejn-log.el
│   └── ejn-test-util.el
│
├── test/                   # ERT test suite
│   ├── ejn-core-test.el
│   ├── ejn-log-test.el
│   ├── ejn-test-util-test.el
│   └── fixtures/
│
├── docs/                   # Documentation
│   ├── architecture.md
│   ├── phase_0_diagrams.md
│   ├── phase_0_specifications.md
│   ├── roadmap.md
│   └── superpowers/
│
└── .opencode/              # Opencode config and skills
    └── skills/
        └── elisp-development/
```

---

### Tips

#### Elisp Development Workflow
- **ALWAYS** activate the `elisp-development` skill before generating, editing, or reviewing any `.el` file.
- After writing or modifying Elisp code, validate it by running `.opencode/skills/elisp-development/scripts/check_elisp.sh <file.el>`. If validation fails, read the output, identify the smallest failing region, repair only that region, and re-run validation until it passes.
- When errors occur, suspect unbalanced parentheses first. Use the skill's structural scan and byte compiler output to locate the issue.

#### Coding Style and Incremental Work
- Use `elisp-dev` as the language identifier for Emacs Lisp documents.
- Write one function or code block at a time. Validate each before moving to the next. Never write an entire file in one pass.

#### Testing and Linting
- Use the `Makefile` for all build operations. Run `make compile`, `make lint`, or `make test` as needed to verify changes.

#### Reference Repositories
When unsure about APIs or conventions, consult these reference repos:
- `emacs-jupyter`: `../Projects/jupyter`
- `code-cells.el`: `../Project/code-cells.el/`
- `emacs-ipython-notebook (ein)`: `../Project/emacs-ipython-notebook/`
