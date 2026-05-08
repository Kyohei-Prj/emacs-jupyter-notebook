# emacs-jupyter-notebook

Emacs-native Jupyter Notebook client.

## Requirements

- Emacs 29+
- Python 3 with Jupyter kernel installed

## Dependencies

### Required
- `dash` — functional programming utilities
- `s` — string manipulation
- `f` — file system utilities
- `compat` — Emacs version compatibility
- `emacs-jupyter` — Jupyter kernel transport (runtime)

### Optional
- `lsp-mode` or `eglot` — language server integration
- `consult` — enhanced navigation
- `transient` — command menus

## Installation

### Via Eask (development)

```bash
eask install
```

### Via MELPA (when available)

```elisp
(use-package emacs-jupyter-notebook
  :ensure t)
```

## Development

```bash
make all      # Compile, lint, and test
make compile  # Byte-compile
make lint     # Run linters
make test     # Run tests
```

## License

GPL-3.0-or-later
