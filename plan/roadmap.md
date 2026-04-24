# `ejn.el` — emacs-jupyter-notebook Package: Development Roadmap

> **Architecture:** Greenfield, LSP-first, indirect-buffer cell model with shadow document
> for cross-cell awareness. Built on `jupyter.el` / `emacs-zmq`, `lsp-mode`, `treesit`,
> and `ewoc`. No dependency on EIN.

---

## Table of Contents

1. [Phase 1 — Project Scaffolding](#phase-1--project-scaffolding)
2. [Phase 2 — Data Model and `.ipynb` I/O](#phase-2--data-model-and-ipynb-io)
3. [Phase 3 — Kernel Communication](#phase-3--kernel-communication)
4. [Phase 4 — Buffer Management and Cell Buffers](#phase-4--buffer-management-and-cell-buffers)
5. [Phase 5 — LSP Integration (Single-Cell)](#phase-5--lsp-integration-single-cell)
6. [Phase 6 — Shadow Buffer and Cross-Cell LSP](#phase-6--shadow-buffer-and-cross-cell-lsp)
7. [Phase 7 — Display Layer (ewoc UI)](#phase-7--display-layer-ewoc-ui)
8. [Phase 8 — Tree-sitter Integration](#phase-8--tree-sitter-integration)
9. [Phase 9 — Output Rendering](#phase-9--output-rendering)
10. [Phase 10 — Polish, Packaging, and Release](#phase-10--polish-packaging-and-release)

---

## Phase 1 — Project Scaffolding

**Goal:** Establish a complete, runnable project skeleton with all directories, base
`.el` files, a test harness, a `Makefile`, and CI configuration. At the end of this
phase the project must compile cleanly, run an empty test suite, and be loadable in a
bare Emacs instance.

---

### 1.1 — Create the Top-level Directory Structure

Create the following directory tree from scratch:

```
ejn.el/
├── ejn.el                     # Package entry point / autoloads
├── lisp/
│   ├── ejn-data.el            # Data model (cells, notebooks)
│   ├── ejn-io.el              # .ipynb parse / serialize
│   ├── ejn-kernel.el          # Kernel communication adapter
│   ├── ejn-buffer.el          # Cell buffer + indirect buffer management
│   ├── ejn-shadow.el          # Shadow/virtual document for cross-cell LSP
│   ├── ejn-lsp.el             # LSP adapter and position translation
│   ├── ejn-display.el         # ewoc-based display layer
│   ├── ejn-output.el          # Output rendering (text, images, HTML)
│   ├── ejn-treesit.el         # Tree-sitter integration helpers
│   └── ejn-util.el            # Shared utilities and macros
├── test/
│   ├── test-helper.el        # Test bootstrap (load path, mocks)
│   ├── ejn-data-test.el       # Tests for data model
│   ├── ejn-io-test.el         # Tests for .ipynb I/O
│   ├── ejn-kernel-test.el     # Tests for kernel adapter (mocked)
│   ├── ejn-buffer-test.el     # Tests for buffer management
│   ├── ejn-shadow-test.el     # Tests for shadow buffer logic
│   └── ejn-lsp-test.el        # Tests for position translation
├── fixtures/
│   ├── simple.ipynb          # Minimal valid notebook (2 Python cells)
│   ├── mixed-lang.ipynb      # Notebook with Python + Markdown cells
│   └── with-outputs.ipynb    # Notebook with text/image outputs
├── docs/
│   ├── ARCHITECTURE.md       # Architecture reference (kept in sync with code)
│   └── CONTRIBUTING.md       # Developer guide
├── .github/
│   └── workflows/
│       └── ci.yml            # GitHub Actions CI
├── Makefile
├── Cask                      # Cask dependency manifest
├── .dir-locals.el            # Project-local Emacs settings
├── .elpaignore               # Files to exclude from ELPA packaging
└── README.md
```

**Action:** Run `mkdir -p` for all directories; `touch` all listed files to create
empty stubs.

---

### 1.2 — Write the Package Entry Point (`ejn.el`)

Populate `ejn.el` with:

- A complete ELPA package header block:
  - `Package-Requires`: `emacs "29.1"`, `jupyter`, `lsp-mode`, `dash`, `s`
  - `Version`, `Author`, `Keywords`, `Homepage` fields
- A `;;; Commentary:` section summarising the architecture (3–5 sentences).
- `(require ...)` calls for each `lisp/ejn-*.el` module, guarded so they only fire
  when not already loaded.
- A `provide` form: `(provide 'ejn)`.
- A `;;; ejn.el ends here` footer.

Do **not** put any functional code here yet; this file is the loader only.

---

### 1.3 — Write Stub Module Files

For each file under `lisp/`, write an identical boilerplate stub:

```elisp
;;; ejn-<module>.el --- <one-line description> -*- lexical-binding: t; -*-

;; Copyright (C) 2025 <Author>

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; <Two-sentence description of what this module will contain.>

;;; Code:

(require 'ejn-util)

;; TODO: implementation

(provide 'ejn-<module>)
;;; ejn-<module>.el ends here
```

Each stub must:
- Use `lexical-binding: t`.
- `require` only `ejn-util` for now (avoids circular dependencies at stub stage).
- Have a correct `provide` and footer comment.

---

### 1.4 — Write `ejn-util.el` (Foundational Utilities)

`ejn-util.el` is the one module that `require`s nothing else in the package.
Implement the following in this task so that subsequent stubs can load cleanly:

- `ejn--debug-p` — a `defvar` controlling debug logging.
- `ejn--log (fmt &rest args)` — a `defun` that writes to `*ejn-log*` buffer when
  `ejn--debug-p` is non-nil.
- `ejn--uuid ()` — generates a v4-like UUID string using `(format "%04x...")` and
  `random`. Does not need to be cryptographically random.
- `ejn--assert (condition message)` — signals `(error message)` if condition is nil;
  used for internal invariant checks throughout the codebase.
- `(provide 'ejn-util)` footer.

---

### 1.5 — Write the `Cask` Dependency File

```
(source gnu)
(source melpa)

(package-file "ejn.el")

(depends-on "emacs" "29.1")
(depends-on "jupyter")
(depends-on "lsp-mode")
(depends-on "dash")
(depends-on "s")

(development
 (depends-on "buttercup")
 (depends-on "el-mock")
 (depends-on "undercover"))
```

---

### 1.6 — Write the `Makefile`

The `Makefile` must support the following targets. Each target must be documented
with a comment:

| Target | Description |
|--------|-------------|
| `make install` | Run `cask install` to fetch all dependencies |
| `make compile` | Byte-compile all `lisp/*.el` files; fail on any warning |
| `make test` | Run the full `buttercup` test suite via `cask exec` |
| `make lint` | Run `package-lint` and `checkdoc` on all source files |
| `make clean` | Remove `*.elc` files and the `.cask/` directory |
| `make all` | `install` → `compile` → `lint` → `test` in sequence |

Key `make compile` invocation:

```makefile
compile:
	cask exec emacs --batch \
	  --eval "(setq byte-compile-error-on-warn t)" \
	  -f batch-byte-compile lisp/*.el ejn.el
```

Include a `.PHONY` declaration for all targets.

---

### 1.7 — Write the Test Helper (`test/test-helper.el`)

`test-helper.el` is loaded by every test file as its first `require`. It must:

- Add `lisp/` and the project root to `load-path`.
- `require` each `ejn-*.el` module.
- Define `ejn-test--fixture-path (name)` — returns the absolute path to a file in
  `fixtures/` by name, so tests can load fixture notebooks without hardcoded paths.
- Define `ejn-test--with-temp-notebook (body-fn)` — a macro that creates a temporary
  copy of `fixtures/simple.ipynb` in a temp directory, runs `body-fn` with the
  temp path, and cleans up afterward.
- `require 'buttercup`, `require 'el-mock`.

---

### 1.8 — Create Notebook Fixture Files

Create the three fixture `.ipynb` files by hand-writing valid JSON conforming to
nbformat 4.5.

**`fixtures/simple.ipynb`:** Two Python code cells, no outputs, no metadata beyond
the minimum required. Cells must have explicit `id` fields (UUIDs).

**`fixtures/mixed-lang.ipynb`:** Three cells — one Markdown, two Python — to
exercise language detection and multi-mode cell buffers.

**`fixtures/with-outputs.ipynb`:** Two Python cells where one has a `text/plain`
output and one has a `image/png` output (a 1×1 pixel PNG encoded in base64) to
provide a target for output rendering tests later.

---

### 1.9 — Write Skeleton Test Files

For each `test/ejn-*-test.el`, write a valid buttercup skeleton:

```elisp
;;; ejn-data-test.el --- Tests for ejn-data.el -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'ejn-data)

(describe "ejn-data"
  (describe "placeholder"
    (it "is always true (remove this when real tests are added)"
      (expect t :to-be t))))

;;; ejn-data-test.el ends here
```

The placeholder test ensures `make test` is green from day one, giving an immediate
CI baseline.

---

### 1.10 — Write `.dir-locals.el`

```elisp
((nil . ((indent-tabs-mode . nil)
         (fill-column . 80)))
 (emacs-lisp-mode . ((indent-tabs-mode . nil)
                     (checkdoc-minor-mode . t))))
```

---

### 1.11 — Write the GitHub Actions CI Workflow

`.github/workflows/ci.yml` must:

- Trigger on `push` to `main` and on all pull requests.
- Use a matrix of Emacs versions: `29.1`, `29.4`, `30.1` (via `purcell/setup-emacs`
  action or equivalent).
- Steps: checkout → install Emacs → `pip install cask` or install Cask via script →
  `make install` → `make compile` → `make test`.
- Upload test results as an artifact on failure.

---

### 1.12 — Write `README.md` (Skeleton)

Include:

- Package name, one-paragraph description, and architecture summary.
- **Status badge** wired to the CI workflow.
- **Sections** (stubs, to be filled in later): Installation, Quick Start, Architecture,
  Contributing, License.
- A note that the package requires Emacs 29.1+ and depends on `jupyter.el` and
  `lsp-mode`.

---

### 1.13 — Phase 1 Validation Checklist

Before proceeding to Phase 2, confirm all of the following manually and via CI:

- [ ] `make install` completes without error.
- [ ] `make compile` produces zero warnings and zero errors.
- [ ] `make test` outputs `X passing` with no failures (placeholder tests only).
- [ ] `make lint` reports no `package-lint` or `checkdoc` errors.
- [ ] All `.el` files load cleanly in a bare Emacs 29.1 with `(require 'ejn)`.
- [ ] CI workflow runs and passes on GitHub.

---

## Phase 2 — Data Model and `.ipynb` I/O

**Goal:** Define the internal data structures that represent a notebook and its cells,
and implement round-trip `.ipynb` (nbformat 4) parsing and serialization using
Emacs's built-in `json` library. All code in this phase is pure data — no buffers,
no kernels, no UI.

---

### 2.1 — Define `ejn-cell` Struct (`ejn-data.el`)

Using `cl-defstruct`, define `ejn-cell` with the following slots:

| Slot | Type | Description |
|------|------|-------------|
| `id` | string | Stable UUID (nbformat 4.5 required field) |
| `type` | symbol | `'code` or `'markdown` or `'raw` |
| `language` | string | Kernel language for code cells; `"markdown"` otherwise |
| `source` | string | Raw cell source text |
| `outputs` | list | List of `ejn-output` structs (see 2.2) |
| `execution-count` | integer or nil | Jupyter execution counter |
| `metadata` | hash-table | Passthrough metadata (preserves unknown keys) |

Provide constructor `ejn-make-cell` and a predicate `ejn-cell-p`. Do not use the
default `cl-defstruct` constructor directly in any public API — wrap it so future
validation logic can be added without touching call sites.

---

### 2.2 — Define `ejn-output` Struct (`ejn-data.el`)

Define `ejn-output` with slots:

| Slot | Type | Description |
|------|------|-------------|
| `output-type` | symbol | `'stream`, `'display_data`, `'execute_result`, `'error` |
| `data` | hash-table | MIME-type → content map (e.g., `"text/plain"` → string) |
| `metadata` | hash-table | Output metadata passthrough |
| `text` | string or nil | Convenience slot for stream outputs |
| `name` | string or nil | Stream name: `"stdout"` or `"stderr"` |

---

### 2.3 — Define `ejn-notebook` Struct (`ejn-data.el`)

Define `ejn-notebook` with slots:

| Slot | Type | Description |
|------|------|-------------|
| `path` | string | Absolute path to the `.ipynb` file |
| `nbformat` | integer | Must be 4 |
| `nbformat-minor` | integer | Typically 5 |
| `metadata` | hash-table | Top-level notebook metadata |
| `kernel-name` | string | e.g., `"python3"` |
| `language` | string | e.g., `"python"` |
| `cells` | list | Ordered list of `ejn-cell` structs |
| `dirty-p` | boolean | Non-nil when unsaved changes exist |

---

### 2.4 — Implement `.ipynb` Parser (`ejn-io.el`)

Implement `ejn-io-read (path)` which:

1. Reads the file at `path` into a string.
2. Parses it with `(json-parse-string ... :object-type 'hash-table :array-type 'list)`.
3. Validates that `nbformat` is 4; signals `(error "Unsupported nbformat: %s" ...)` otherwise.
4. Constructs and returns an `ejn-notebook` struct by mapping over the `"cells"` array
   and calling a private `ejn-io--parse-cell` helper for each element.
5. Preserves all unknown metadata keys in the passthrough `metadata` hash-table.

Implement private helper `ejn-io--parse-cell (raw-cell)` which dispatches on the
`"cell_type"` field and constructs the appropriate `ejn-cell` struct, joining the
`"source"` array into a single string.

Implement private helper `ejn-io--parse-output (raw-output)` which constructs an
`ejn-output` struct.

---

### 2.5 — Implement `.ipynb` Serializer (`ejn-io.el`)

Implement `ejn-io-write (notebook path)` which:

1. Converts the `ejn-notebook` struct back to a JSON-serializable Elisp structure
   (nested hash-tables and lists mirroring the nbformat schema).
2. Splits `source` strings back into arrays of lines (nbformat convention).
3. Writes the result with `(json-encode ...)` to `path`, using pretty-printing
   (2-space indent).
4. Sets `(ejn-notebook-dirty-p notebook)` to `nil` after a successful write.

The round-trip invariant — `(ejn-io-read (ejn-io-write nb path))` should produce a
structurally identical notebook — must be testable and will be verified in 2.7.

---

### 2.6 — Implement Cell Manipulation Helpers (`ejn-data.el`)

These functions operate on `ejn-notebook` structs and return new structs (do not
mutate in place, to simplify undo and testing):

- `ejn-notebook-insert-cell (notebook cell index)` — returns a new notebook with `cell`
  inserted at `index` in the cell list.
- `ejn-notebook-delete-cell (notebook uuid)` — returns a new notebook with the cell
  matching `uuid` removed.
- `ejn-notebook-move-cell (notebook uuid direction)` — `direction` is `'up` or `'down`;
  returns a new notebook with the cell reordered.
- `ejn-notebook-cell-by-id (notebook uuid)` — returns the `ejn-cell` with matching `id`
  or `nil`.
- `ejn-notebook-update-cell-source (notebook uuid new-source)` — returns a new notebook
  with the named cell's `source` updated and `dirty-p` set to `t`.

---

### 2.7 — Write Data Model and I/O Tests

In `ejn-data-test.el` and `ejn-io-test.el`:

- Test struct construction and slot access for `ejn-cell`, `ejn-output`, `ejn-notebook`.
- Test `ejn-io-read` against `fixtures/simple.ipynb`: verify cell count, UUIDs,
  source text, and `kernel-name`.
- Test `ejn-io-read` against `fixtures/mixed-lang.ipynb`: verify cell types.
- Test `ejn-io-read` against `fixtures/with-outputs.ipynb`: verify output struct
  construction including the base64 PNG slot.
- Test the round-trip invariant: read a fixture, write to a temp file, re-read, and
  compare cell UUIDs and source text.
- Test each of the cell manipulation helpers in `ejn-data.el`, including edge cases
  (insert at 0, delete the only cell, move first cell up, move last cell down).

---

## Phase 3 — Kernel Communication

**Goal:** Build a thin adapter on top of `jupyter.el` that manages kernel
lifecycle (start, stop, restart, interrupt) and provides a clean async API for
`execute_request` and `completion_request` that the rest of the package uses. The
`jupyter.el` ZMQ internals are not reimplemented.

---

### 3.1 — Define the Kernel Manager Struct (`ejn-kernel.el`)

Define `ejn-kernel-manager` with slots:

| Slot | Description |
|------|-------------|
| `notebook-path` | The notebook this manager belongs to |
| `kernel-name` | e.g., `"python3"` |
| `client` | The underlying `jupyter-kernel-client` object |
| `status` | Symbol: `'starting`, `'idle`, `'busy`, `'dead` |
| `pending-requests` | Hash-table mapping `request-id` → `(cell-uuid . callback)` |

---

### 3.2 — Implement Kernel Lifecycle Functions (`ejn-kernel.el`)

- `ejn-kernel-start (notebook callback)` — starts a kernel for the given `ejn-notebook`
  using `jupyter-start-kernel` with the notebook's `kernel-name`. Calls `callback`
  with the `ejn-kernel-manager` when the kernel is ready. Updates `status`.
- `ejn-kernel-stop (manager)` — gracefully shuts down the kernel; updates `status`
  to `'dead`.
- `ejn-kernel-restart (manager callback)` — stops then starts; calls `callback` when
  ready.
- `ejn-kernel-interrupt (manager)` — sends an interrupt signal.
- `ejn-kernel-status (manager)` — returns the current `status` symbol.

---

### 3.3 — Implement `execute_request` (`ejn-kernel.el`)

Implement `ejn-kernel-execute (manager cell-uuid source callbacks)` where `callbacks`
is a plist:

```elisp
(:on-output   (lambda (output-struct) ...)
 :on-complete (lambda (execution-count) ...)
 :on-error    (lambda (ename evalue traceback) ...))
```

The function must:
1. Send an `execute_request` message via `jupyter-execute-request`.
2. Register the `request-id` in `pending-requests` keyed by `cell-uuid`.
3. Route incoming `execute_result`, `stream`, `display_data`, and `error` messages
   to the appropriate callback by looking up `request-id` in `pending-requests`.
4. Construct an `ejn-output` struct from each incoming message before passing to
   `:on-output`.
5. Remove the entry from `pending-requests` on `idle` kernel status for that request.

---

### 3.4 — Implement `completion_request` (`ejn-kernel.el`)

Implement `ejn-kernel-complete (manager source cursor-pos callback)` where `callback`
receives a list of completion strings. This is used by the LSP adapter as a fallback
when the language server is unavailable or for non-Python kernels.

---

### 3.5 — Implement Kernel Status Hook (`ejn-kernel.el`)

Provide `ejn-kernel-status-hook` (an abnormal hook) that is run whenever kernel status
changes. Signature: `(manager old-status new-status)`. The display layer will use
this hook to update the status indicator in the UI.

---

### 3.6 — Write Kernel Tests with Mocks

In `ejn-kernel-test.el`, use `el-mock` to mock `jupyter-start-kernel` and
`jupyter-execute-request`. Tests must cover:

- Kernel start: verify `status` transitions to `'idle`.
- Execute request: verify that the `:on-output` callback is called with a correctly
  constructed `ejn-output` struct when a mocked response is delivered.
- Execute request error: verify `:on-error` callback is called.
- Pending request cleanup: verify `pending-requests` is empty after completion.
- Status hook: verify the hook fires on each status transition.

---

## Phase 4 — Buffer Management and Cell Buffers

**Goal:** Implement the core buffer management layer. Each code cell gets a real
Emacs indirect buffer narrowed to its region in the notebook display buffer. Cell
buffers have stable identities (keyed by cell UUID), support major modes, and survive
cell reordering. This is the architectural keystone that enables LSP.

---

### 4.1 — Define the Buffer Registry (`ejn-buffer.el`)

Define a buffer-local variable `ejn--cell-registry` (a hash-table mapping
`cell-uuid` → `ejn-cell-state` struct) stored on the notebook display buffer.

Define `ejn-cell-state` with slots:

| Slot | Description |
|------|-------------|
| `cell` | The `ejn-cell` struct |
| `direct-buffer` | The indirect buffer for this cell |
| `start-marker` | Marker at the start of the cell region in the display buffer |
| `end-marker` | Marker at the end of the cell region in the display buffer |
| `modified-tick` | `buffer-chars-modified-tick` at last sync |

---

### 4.2 — Implement Indirect Buffer Creation (`ejn-buffer.el`)

Implement `ejn-buffer-make-cell-buffer (display-buffer cell)`:

1. Creates an indirect buffer via `make-indirect-buffer` with name
   ` *ejn-cell-<uuid>*` (leading space makes it invisible in `C-x b`).
2. Narrows the indirect buffer to the cell's region (via markers from the registry).
3. Sets the appropriate major mode: calls `ejn-treesit--mode-for-language` (Phase 8
   will implement this; for now use a stub that returns `python-ts-mode`).
4. Sets `buffer-file-name` to a synthetic path:
   `/tmp/ejn-cells/<notebook-basename>/<uuid>.<ext>` — this is the URI the LSP
   server will use.
5. Sets `ejn--cell-uuid` buffer-local to the cell's UUID.
6. Does **not** call `lsp` yet (that is Phase 5).
7. Returns the indirect buffer.

---

### 4.3 — Implement Buffer Registry Operations (`ejn-buffer.el`)

- `ejn-buffer-register-cell (display-buffer cell start end)` — creates an
  `ejn-cell-state`, registers it, creates the indirect buffer, and returns the
  `ejn-cell-state`.
- `ejn-buffer-unregister-cell (display-buffer uuid)` — kills the indirect buffer,
  removes the entry from the registry.
- `ejn-buffer-get-state (display-buffer uuid)` — returns the `ejn-cell-state` or nil.
- `ejn-buffer-cell-buffer (display-buffer uuid)` — returns the indirect buffer or nil.
- `ejn-buffer-all-cell-buffers (display-buffer)` — returns a list of all currently
  live indirect buffers for the notebook.

---

### 4.4 — Implement Source Synchronization (`ejn-buffer.el`)

Cell source text must stay in sync between the cell's `ejn-cell` struct and its
indirect buffer. Implement a two-way sync mechanism:

- `ejn-buffer--sync-to-struct (cell-state)` — reads the text from the indirect
  buffer, compares `buffer-chars-modified-tick` against `modified-tick`, and if
  changed, calls `ejn-notebook-update-cell-source` to produce an updated notebook
  struct. Stores the new tick.
- `ejn-buffer--sync-from-struct (cell-state)` — writes `(ejn-cell-source cell)` into
  the indirect buffer region if the struct's source differs from buffer content.
  Used when a cell is updated programmatically (e.g., remote kernel output).
- Add `after-change-functions` hook on each indirect buffer that calls
  `ejn-buffer--sync-to-struct` with a short idle timer (0.3 s debounce) to avoid
  excessive syncing while typing.

---

### 4.5 — Implement Cell Buffer Teardown (`ejn-buffer.el`)

Implement `ejn-buffer-teardown-notebook (display-buffer)`:

1. Iterates all entries in `ejn--cell-registry`.
2. For each, calls `ejn-buffer-unregister-cell`.
3. Clears the registry hash-table.

Register this function on `kill-buffer-hook` for the display buffer.

---

### 4.6 — Write Buffer Management Tests

In `ejn-buffer-test.el`:

- Test `ejn-buffer-make-cell-buffer`: verify the returned buffer is live, is indirect,
  and has the correct narrowing boundaries.
- Test `ejn-buffer-register-cell` / `ejn-buffer-unregister-cell`: verify the registry
  is correctly populated and emptied.
- Test sync `ejn-buffer--sync-to-struct`: simulate a text change in the indirect buffer
  and verify the `ejn-cell` struct's `source` is updated.
- Test sync `ejn-buffer--sync-from-struct`: update a struct's source programmatically
  and verify the indirect buffer text changes.
- Test teardown: verify all indirect buffers are killed and the registry is empty.

---

## Phase 5 — LSP Integration (Single-Cell)

**Goal:** Integrate `lsp-mode` into individual cell buffers. Each cell indirect buffer
registers with the LSP server independently. Completions, hover, and diagnostics must
work for a single cell in isolation before cross-cell work begins in Phase 6.

---

### 5.1 — Define LSP Workspace Root Resolution (`ejn-lsp.el`)

Implement `ejn-lsp--workspace-root (notebook-path)` which returns the directory
containing the `.ipynb` file. This is set as `lsp-workspace-root` for all cell
buffers belonging to the same notebook, so they share a single LSP server instance.

---

### 5.2 — Activate LSP on Cell Buffers (`ejn-lsp.el`)

Implement `ejn-lsp-activate-cell (cell-buffer notebook-path)`:

1. Sets `lsp-enabled-clients` to restrict to appropriate clients for the cell's
   language (e.g., `pylsp` or `pyright` for Python).
2. Sets `lsp-auto-guess-root` to nil and manually provides the workspace root via
   `ejn-lsp--workspace-root`.
3. Calls `(lsp)` to start the LSP client for this buffer.
4. Registers a `lsp-on-idle-hook` to trigger shadow buffer sync (Phase 6 will
   implement the target; install a no-op stub now).

Extend `ejn-buffer-make-cell-buffer` (Phase 4.2) to call `ejn-lsp-activate-cell`
after mode setup.

---

### 5.3 — Configure `lsp-mode` Compatibility Settings (`ejn-lsp.el`)

In a `with-eval-after-load 'lsp-mode` block, configure the following to prevent
`lsp-mode`'s default behaviour from conflicting with indirect buffers:

- Set `lsp-keep-workspace-alive` to nil (so the workspace is cleaned up when the
  notebook is closed, not kept alive by buffer-kill detection).
- Disable `lsp-headerline-breadcrumb-mode` for cell buffers (visual noise in
  indirect buffers).
- Set `lsp-diagnostics-provider` to `:flycheck` or `:flymake` per user preference
  (expose as a `defcustom` variable `ejn-lsp-diagnostics-provider`).

---

### 5.4 — Handle LSP `textDocument/didOpen` and `didClose` Lifecycle (`ejn-lsp.el`)

LSP servers track the open/closed state of each document. Implement:

- `ejn-lsp--on-cell-open (cell-buffer)` — advises `lsp--text-document-did-open` to
  ensure cell buffers send the correct `uri` (the synthetic `/tmp/ejn-cells/...` path,
  not the display buffer's path).
- `ejn-lsp--on-cell-close (cell-buffer)` — ensures `textDocument/didClose` is sent
  when a cell buffer is killed. Add to the `kill-buffer-hook` of each cell buffer.

---

### 5.5 — Implement LSP URI Helpers (`ejn-lsp.el`)

- `ejn-lsp--cell-uri (notebook-path uuid language)` — constructs the synthetic file
  URI for a cell buffer: `file:///tmp/ejn-cells/<hash>/<uuid>.<ext>`.
- `ejn-lsp--ext-for-language (language)` — maps language string to file extension:
  `"python"` → `"py"`, `"julia"` → `"jl"`, `"r"` → `"r"`, etc.
- Ensure `buffer-file-name` on each cell buffer is set to the path form of the URI
  (without `file://` prefix) so `lsp--buffer-uri` returns the correct value.

---

### 5.6 — Write LSP Single-Cell Integration Tests

In `ejn-lsp-test.el`:

- Test `ejn-lsp--workspace-root` returns the directory of the notebook path.
- Test `ejn-lsp--cell-uri` produces a correctly formed URI for known languages.
- Test `ejn-lsp--ext-for-language` for all supported languages including an unknown
  language fallback (should return `"txt"`).
- Test that `ejn-lsp-activate-cell` sets `buffer-file-name` correctly on a mock
  indirect buffer (mock out `(lsp)` itself to avoid a real server dependency in CI).

---

## Phase 6 — Shadow Buffer and Cross-Cell LSP

**Goal:** Implement the shadow (virtual) document that concatenates all same-language
cells in notebook order. Maintain it in real time as cells change. Implement
position translation so LSP responses from the shadow buffer can be mapped back to
the originating cell buffer. This phase delivers cross-cell "go to definition",
completions that see imports from earlier cells, and whole-notebook diagnostics.

---

### 6.1 — Define the Shadow Buffer Struct (`ejn-shadow.el`)

Define `ejn-shadow-state` (stored buffer-local on the display buffer) with slots:

| Slot | Description |
|------|-------------|
| `buffer` | The live shadow buffer |
| `path` | Synthetic file path (`/tmp/ejn-shadow/<name>.py`) |
| `offset-table` | Sorted vector of `(uuid . char-offset)` pairs |
| `dirty-p` | Non-nil when an update is pending |
| `idle-timer` | The current `run-with-idle-timer` object |

---

### 6.2 — Implement Shadow Buffer Creation (`ejn-shadow.el`)

Implement `ejn-shadow-create (notebook display-buffer)`:

1. Creates a real (non-indirect) buffer named `" *ejn-shadow-<basename>*"`.
2. Sets `buffer-file-name` to the synthetic `.py` path.
3. Populates the buffer by calling `ejn-shadow--rebuild` (see 6.3).
4. Activates `lsp` on the shadow buffer with the same workspace root as cell buffers.
5. Stores the `ejn-shadow-state` buffer-locally on the display buffer.

---

### 6.3 — Implement Shadow Buffer Rebuild (`ejn-shadow.el`)

Implement `ejn-shadow--rebuild (shadow-state notebook)`:

1. Clears the shadow buffer.
2. Iterates cells in notebook order; skips non-code cells and cells whose language
   does not match the notebook's primary language.
3. For each code cell, inserts a sentinel comment `# cell:<uuid>` followed by the
   cell's source text and a trailing newline.
4. Records the character offset of each cell's source start into `offset-table` as
   a sorted vector.
5. Sends `textDocument/didChange` to the LSP server for the shadow buffer (via
   `lsp-notify`).

---

### 6.4 — Implement Incremental Shadow Updates (`ejn-shadow.el`)

Implement `ejn-shadow--update-cell (shadow-state uuid new-source)`:

Instead of full rebuild on every keystroke, replace only the text belonging to `uuid`
in the shadow buffer:

1. Look up the cell's region in the shadow buffer using the offset table (binary search
   via `seq-position` or a manual loop).
2. Replace the old source text with `new-source` using `replace-region-contents`.
3. Recompute all offsets after the modified cell's position (a single O(n) pass over
   the remaining entries in `offset-table`).
4. Send an incremental `textDocument/didChange` notification.

Wire this function to the `after-change-functions` idle timer in `ejn-buffer.el`
(Phase 4.4): after syncing to the struct, also call `ejn-shadow--update-cell`.

---

### 6.5 — Implement Position Translation (`ejn-shadow.el`)

Implement `ejn-shadow-shadow-pos-to-cell (shadow-state shadow-char-pos)`:

- Returns `(uuid . cell-char-pos)` where `cell-char-pos` is the position within
  that cell's source string.
- Uses binary search on `offset-table` to find the cell whose offset range contains
  `shadow-char-pos`.
- Returns nil if the position falls within a sentinel comment line.

Implement `ejn-shadow-cell-pos-to-shadow (shadow-state uuid cell-char-pos)`:

- Returns the absolute character position in the shadow buffer corresponding to
  `cell-char-pos` within the cell identified by `uuid`.

---

### 6.6 — Implement Cross-Cell LSP Request Routing (`ejn-lsp.el`)

Wire the shadow buffer into LSP completions and definitions:

- **Completions:** Advise `lsp-completion-at-point` in cell buffers to additionally
  query the shadow buffer's LSP session, then merge results, deduplicating by
  `:label`. Shadow completions are particularly valuable for names defined in earlier
  cells.
- **Go to definition:** Advise `lsp-find-definition`: if the target location resolves
  to the shadow buffer path, call `ejn-shadow-shadow-pos-to-cell` and jump to the
  corresponding cell buffer at the translated position using `xref-push-marker-stack`
  and `goto-char`.
- **Hover:** Prefer the shadow buffer's hover result when the cell buffer's result is
  nil (e.g., for symbols imported in a previous cell).

---

### 6.7 — Write Shadow Buffer Tests

In `ejn-shadow-test.el`:

- Test `ejn-shadow--rebuild`: verify the shadow buffer's text matches the expected
  concatenation of cell sources with sentinels.
- Test `ejn-shadow--update-cell`: modify one cell's source and verify only that cell's
  region in the shadow buffer changes and all other content is unchanged.
- Test `ejn-shadow-shadow-pos-to-cell`: given known offsets, verify correct
  `(uuid . pos)` is returned; test a position in a sentinel line returns nil.
- Test `ejn-shadow-cell-pos-to-shadow`: verify correct shadow position for a given
  cell UUID and cell-relative position.
- Test offset table recomputation after a cell's source grows and shrinks.

---

## Phase 7 — Display Layer (ewoc UI)

**Goal:** Build the read-only notebook display buffer using `ewoc`. Each cell is an
ewoc node. The display must be fast to render, update incrementally (only dirty
nodes), and correctly delegate keyboard input to cell indirect buffers.

---

### 7.1 — Define the ewoc Node Data Structure (`ejn-display.el`)

Define `ejn-display-node` with slots:

| Slot | Description |
|------|-------------|
| `uuid` | Cell UUID |
| `cell-type` | `'code`, `'markdown`, `'raw` |
| `language` | Language string |
| `collapsed-p` | Whether the cell is collapsed |
| `executing-p` | Whether the cell is currently executing |
| `execution-count` | Last execution count or nil |

---

### 7.2 — Implement the ewoc Pretty-Printer (`ejn-display.el`)

Implement `ejn-display--pp-node (node-data)` — the ewoc pretty-printer function
called for each node. It must render:

- A header line: `[<language>] In [<count>]:` with a status indicator (●=idle,
  ◐=executing, ✗=error) using text properties for colour.
- The cell source text, pulled from the corresponding indirect buffer (not the
  struct) so edits made directly in the indirect buffer are reflected on refresh.
- A separator line between cells.

Apply `read-only` text properties to header and separator lines. Leave the source
region writable (or delegate write access to the indirect buffer).

---

### 7.3 — Implement the Notebook Display Buffer (`ejn-display.el`)

Implement `ejn-display-create (notebook)` which:

1. Creates a buffer named `*ejn: <basename>*`.
2. Initialises an `ewoc` with `ejn-display--pp-node` as the printer.
3. For each cell in the notebook, calls `ejn-buffer-register-cell` (Phase 4) then
   `ewoc-enter-last` to add a node.
4. Starts the kernel via `ejn-kernel-start` (Phase 3) and stores the manager
   buffer-locally.
5. Creates the shadow buffer via `ejn-shadow-create` (Phase 6).
6. Sets the buffer to `ejn-mode` (see 7.5).

---

### 7.4 — Implement Incremental Node Refresh (`ejn-display.el`)

Implement `ejn-display-refresh-cell (display-buffer uuid)` — invalidates and
redraws only the ewoc node for `uuid` using `ewoc-invalidate`. This is called by:

- The `after-change-functions` idle timer when a cell's source changes.
- The `ejn-kernel-status-hook` when execution state changes.
- The output rendering layer (Phase 9) when new output arrives.

Avoid calling `ewoc-refresh` (full redraw) except when cells are inserted, deleted,
or reordered.

---

### 7.5 — Define `ejn-mode` (Major Mode for Display Buffer) (`ejn-display.el`)

Derive `ejn-mode` from `special-mode`. Key bindings (minimal set for this phase):

| Key | Function |
|-----|----------|
| `RET` / `e` | `ejn-display-edit-cell-at-point` — pop cell buffer in side window |
| `C-c C-c` | `ejn-display-execute-cell-at-point` |
| `C-c C-n` | `ejn-display-insert-cell-below` |
| `C-c C-d` | `ejn-display-delete-cell-at-point` |
| `C-c C-k` | `ejn-kernel-interrupt` |
| `C-c C-s` | `ejn-io-write` (save notebook) |
| `M-Up` / `M-Down` | `ejn-display-move-cell-up` / `ejn-display-move-cell-down` |
| `q` | `ejn-display-teardown` (close notebook, kill all buffers) |

---

### 7.6 — Implement Cell Editing Pop-up (`ejn-display.el`)

Implement `ejn-display-edit-cell-at-point ()`:

1. Determines the UUID of the cell under point (by walking ewoc nodes).
2. Retrieves the indirect buffer from the registry.
3. Displays it in a side window (`display-buffer-in-side-window`) with
   `(side . bottom)` and a configurable height.
4. Sets focus to the side window.

The user edits directly in the indirect buffer. Changes propagate back to the display
buffer via the sync mechanism from Phase 4.4.

---

### 7.7 — Implement Cell Insert, Delete, and Reorder (`ejn-display.el`)

- `ejn-display-insert-cell-below (uuid language)` — creates a new `ejn-cell` (fresh UUID),
  calls `ejn-buffer-register-cell`, inserts an ewoc node after the current node, and
  updates the notebook struct.
- `ejn-display-delete-cell-at-point ()` — confirms with user, calls
  `ejn-buffer-unregister-cell`, removes the ewoc node, updates the notebook struct.
- `ejn-display-move-cell-up/down ()` — swaps ewoc node positions, updates marker
  positions, rebuilds the offset table in the shadow buffer, triggers shadow buffer
  full rebuild.

---

## Phase 8 — Tree-sitter Integration

**Goal:** Each cell buffer activates the correct `*-ts-mode` automatically based on
the cell's language. Provide structured navigation (move to next/previous function,
class, etc.) within cells.

---

### 8.1 — Implement Language-to-Mode Mapping (`ejn-treesit.el`)

Implement `ejn-treesit--mode-for-language (language)` as a dispatch table:

```
"python"     → python-ts-mode
"r"          → (if available) r-ts-mode, else ess-r-mode
"julia"      → julia-ts-mode (if available)
"javascript" → js-ts-mode
"typescript" → typescript-ts-mode
"markdown"   → markdown-mode
"bash"       → bash-ts-mode
_            → fundamental-mode
```

Expose `ejn-treesit-language-mode-alist` as a `defcustom` so users can extend or
override the mapping without modifying package code.

---

### 8.2 — Implement Tree-sitter Grammar Availability Check (`ejn-treesit.el`)

Implement `ejn-treesit-grammar-available-p (language)` — wraps
`treesit-language-available-p` and caches the result in a hash-table to avoid
repeated checks. This is used by `ejn-treesit--mode-for-language` to gracefully fall
back to non-ts modes when a grammar is not installed.

---

### 8.3 — Implement Structured Navigation (`ejn-treesit.el`)

Using `treesit-*` functions, implement:

- `ejn-treesit-next-defun ()` — moves point to the next function or class definition
  in the current cell buffer.
- `ejn-treesit-prev-defun ()` — moves to the previous function or class definition.
- `ejn-treesit-node-at-point ()` — returns a string description of the treesit node
  under point (used for debugging and future context-aware features).

Bind these in a `ejn-cell-mode-map` minor mode that is activated in all cell indirect
buffers.

---

### 8.4 — Write Tree-sitter Tests

- Test `ejn-treesit--mode-for-language` for all known languages.
- Test that unknown languages return `fundamental-mode`.
- Test `ejn-treesit-grammar-available-p` returns a boolean without error for both an
  installed and a fake/absent language.

---

## Phase 9 — Output Rendering

**Goal:** Display cell outputs (text, errors, images, HTML) in the notebook display
buffer beneath each cell. Output must be rendered incrementally as it arrives from
the kernel, not batched at execute completion.

---

### 9.1 — Define the Output Display Region (`ejn-output.el`)

For each cell ewoc node, maintain a separate output region immediately below the cell
source region. This region uses `read-only` and `inhibit-modification-hooks` text
properties. Implement:

- `ejn-output--output-start-marker (display-buffer uuid)` — returns a marker at the
  start of the output region for cell `uuid`.
- `ejn-output--clear-outputs (display-buffer uuid)` — deletes all content in the
  output region (called when re-executing a cell).

---

### 9.2 — Implement Text/Stream Output Rendering (`ejn-output.el`)

Implement `ejn-output-render-stream (display-buffer uuid output-struct)`:

- Inserts `(ejn-output-text output-struct)` at the end of the output region.
- Applies `font-lock` faces: `stdout` in default face, `stderr` in warning face.
- Ensures the insertion respects `read-only` properties on surrounding regions.

---

### 9.3 — Implement Error Output Rendering (`ejn-output.el`)

Implement `ejn-output-render-error (display-buffer uuid output-struct)`:

- Renders the traceback lines with ANSI escape code support (use `ansi-color-apply`).
- Highlights the exception name in `error` face.
- Truncates tracebacks longer than `ejn-output-max-traceback-lines` (a `defcustom`,
  default 20) with a `[truncated]` indicator.

---

### 9.4 — Implement Image Output Rendering (`ejn-output.el`)

Implement `ejn-output-render-image (display-buffer uuid output-struct)`:

1. Extracts the `image/png` or `image/jpeg` entry from `(ejn-output-data output-struct)`.
2. Decodes the base64 data using `base64-decode-string`.
3. Creates an Emacs image with `(create-image data 'png t)`.
4. Inserts the image using `insert-image` in the output region.
5. Falls back to displaying `[image/png: <N> bytes]` text if `display-images-p`
   returns nil (e.g., in terminal Emacs).

---

### 9.5 — Wire Output Rendering to Kernel Callbacks (`ejn-output.el`)

Implement `ejn-output-make-kernel-callbacks (display-buffer uuid)` which returns a
`callbacks` plist suitable for passing to `ejn-kernel-execute` (Phase 3.3):

- `:on-output` — dispatches to the appropriate renderer based on `output-type`.
- `:on-complete` — updates the execution count in the ewoc node data; calls
  `ejn-display-refresh-cell`; sets the status indicator to idle.
- `:on-error` — calls `ejn-output-render-error`; sets the status indicator to error.

---

## Phase 10 — Polish, Packaging, and Release

**Goal:** Harden the package for public release. Improve error handling, write user
documentation, configure MELPA submission, and ensure the package works on all
supported Emacs versions.

---

### 10.1 — Comprehensive Error Handling Audit

Review every public function for unguarded failure modes:

- Wrap kernel communication in `condition-case` and display user-friendly messages
  via `message` or `user-error` rather than raw `error` signals.
- Handle the case where the `jupyter.el` or `lsp-mode` package is not installed
  with a clear `user-error` at load time.
- Add guards for indirect buffer death (the parent buffer was killed): check
  `buffer-live-p` before every indirect buffer operation.

---

### 10.2 — Custom Variables and Faces Audit

Ensure all user-facing settings are `defcustom` with `:group 'ejn` and meaningful
`:type` declarations. All display faces must be `defface` with reasonable defaults
for both light and dark themes. Confirm `M-x customize-group RET ejn` shows a
coherent settings page.

---

### 10.3 — Write the User Manual (`docs/MANUAL.md` + Info node)

Document:

- Installation (via MELPA, via `use-package`).
- Prerequisites: Emacs 30.1+, `jupyter.el`, `lsp-mode`, a Jupyter kernel installed
  on the system.
- Opening a notebook: `M-x ejn-open-file`.
- Key bindings reference table.
- Configuring LSP providers per language.
- Troubleshooting: LSP not starting, kernel not found, no treesit grammar.

Generate an Info node from the manual using Pandoc or `org-export`.

---

### 10.4 — Performance Profiling

Profile the following scenarios with `M-x profiler-start` and identify any function
consuming more than 5% of CPU during normal editing:

- Typing in a cell with 500-line source and 20 cells total.
- Executing a cell that produces 10,000 lines of stream output.
- Opening a notebook with 50 cells.

Address any identified hotspots, paying particular attention to shadow buffer
rebuilds and offset table recomputation.

---

### 10.5 — MELPA Recipe and Submission

Create a MELPA recipe file:

```elisp
(ejn :fetcher github
    :repo "<your-username>/ejn.el"
    :files ("*.el" "lisp/*.el"))
```

Submit a pull request to the MELPA repository. Ensure:

- `package-lint` reports zero errors or warnings.
- `checkdoc` reports zero errors or warnings.
- The package builds cleanly via MELPA's CI infrastructure.

---

### 10.6 — Final Test Suite Expansion

Expand the test suite to achieve the following coverage targets:

| Module | Target Coverage |
|--------|----------------|
| `ejn-data.el` | 95% |
| `ejn-io.el` | 90% |
| `ejn-kernel.el` | 80% (kernel mocked) |
| `ejn-buffer.el` | 85% |
| `ejn-shadow.el` | 90% |
| `ejn-lsp.el` | 75% (LSP mocked) |
| `ejn-output.el` | 80% |

Use `undercover.el` to generate coverage reports in CI and post them as a PR
comment via a GitHub Actions step.

---

### 10.7 — Release Checklist

- [ ] All Phase 1–10 validation checklists passing.
- [ ] CI green on Emacs 29.1, 29.4, and 30.1.
- [ ] MELPA recipe accepted.
- [ ] `CHANGELOG.md` written for v0.1.0.
- [ ] GitHub release tagged `v0.1.0` with release notes.
- [ ] README badges updated (CI, MELPA, license).

---

## Phase Dependencies Summary

```
Phase 1 (Scaffolding)
    └── Phase 2 (Data Model + I/O)
            └── Phase 3 (Kernel Communication)
            └── Phase 4 (Buffer Management)
                    └── Phase 5 (LSP Single-Cell)
                            └── Phase 6 (Shadow Buffer + Cross-Cell LSP)
                    └── Phase 7 (Display Layer)
                            └── Phase 9 (Output Rendering)
                    └── Phase 8 (Tree-sitter)
Phase 6 + Phase 7 + Phase 8 + Phase 9
    └── Phase 10 (Polish + Release)
```

Phases 3, 4, and 8 can be developed in parallel after Phase 2 is complete.
Phases 5 and 7 can be started simultaneously once Phase 4 is complete.
Phase 6 requires both Phase 4 and Phase 5. Phase 9 requires both Phase 3 and Phase 7.
