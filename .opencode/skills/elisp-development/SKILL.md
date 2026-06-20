---
name: elisp-development
description: Generate, validate, lint, normalize, and repair Emacs Lisp using compiler-assisted structural verification workflows.
license: MIT
compatibility: opencode
metadata:
  language: elisp
  workflow: validation-loop
  strategy: compiler-assisted-generation
---

# Elisp Development Skill

This skill provides a structured workflow for reliable Emacs Lisp generation.

The workflow is:

1. Generate modular Elisp
2. Run structural validation
3. Run AST traversal checks
4. Run compiler checks
5. Run lint passes
6. Normalize forms
7. Repair only damaged regions
8. Re-run validation
9. Return only validated code

---

# Generation Rules

Always follow these rules when generating Elisp:

- Prefer shallow nesting
- Prefer helper functions over deeply nested expressions
- Maximum recommended nesting depth: 4
- Avoid large anonymous lambdas
- Avoid nested condition-case blocks
- Prefer `pcase` over deeply nested `cond`
- Prefer lexical binding
- Use explicit docstrings
- Keep functions under ~30 LOC when practical
- Add section comments for large forms
- Preserve indentation consistency

---

# Required File Header

Always generate:

```elisp
;;; file-name.el --- Description -*- lexical-binding: t; -*-
````

---

# Structural Formatting Rules

Use stable indentation.

Example:

```elisp
(let ((value x))
  (when value
    (message "%s" value))) ; end when
```

Add closing comments for deeply nested forms when useful.

---

# Mandatory Validation Workflow

After generating code:

1. Save to temporary `.el`
2. Execute:

```bash
scripts/check_elisp.sh FILE.el
```

3. If validation fails:

   * Read compiler/linter output
   * Identify smallest invalid region
   * Repair only that region
   * Re-run validation

Never return unvalidated Elisp.

---

# Structural Validation Requirements

Validation must include:

* `check-parens`
* `forward-sexp` traversal
* byte compilation
* indentation normalization
* optional linting

---

# Failure Recovery Strategy

If validation fails:

## Parenthesis Errors

Typical compiler messages:

* End of file during parsing
* Invalid read syntax
* Scan error

Actions:

* Inspect nearest unmatched form
* Compare indentation drift
* Regenerate smallest enclosing form only

## Byte Compiler Warnings

Treat warnings as weighted repair signals.

Severity levels:

| Severity | Examples            |
| -------- | ------------------- |
| Critical | parse failures      |
| High     | malformed function  |
| High     | free variables      |
| Medium   | obsolete APIs       |
| Low      | unused lexical args |

---

# AST Traversal Validation

Always validate form navigability:

```elisp
(forward-sexp)
(backward-sexp)
(scan-sexps ...)
```

Balanced parentheses alone are insufficient.

---

# Normalization Strategy

Normalize generated forms using pretty-printing.

Large normalization drift indicates malformed structure.

---

# Preferred Repair Strategy

Prefer:

```text
repair subtree
```

Instead of:

```text
regenerate entire file
```

---

# Recommended Optional Tools

Use when available:

* package-lint
* checkdoc
* relint
* Elsa

---

# Completion Criteria

Only finalize code if ALL pass:

* Parentheses balanced
* Structural traversal valid
* Byte compilation succeeds
* Indentation stable
* Lint severity acceptable

If any critical validation fails:
DO NOT finalize.

---
