# Emacs Jupyter Notebook (EJN)

EJN is a next-generation Emacs package for editing and executing Jupyter Notebook (`.ipynb`) files. It replaces the aging EIN (Emacs IPython Notebook) with a modern architecture that provides full **Language Server Protocol (LSP)** support, **Polymode**-based multi-mode editing, and a **global undo** system spanning all cells.

## Architecture

EJN solves the fundamental problem of LSP incompatibility in notebook editors through a **"one-cell-one-buffer"** design:

```
.ipynb file
├── ejn-notebook (EIEIO object, in-memory model)
│   ├── ejn-cell[0] ──→ *ejn-cell:cell-001* buffer ──→ .ejn-cache/nb-stem/cell_000.py (shadow file)
│   ├── ejn-cell[1] ──→ *ejn-cell:cell-002* buffer ──→ .ejn-cache/nb-stem/cell_001.py (shadow file)
│   └── ...
├── *ejn-master:notebook.ipynb* (Polymode master view, all cells rendered with delimiters)
└── .ejn-cache/nb-stem/composite.py  (concatenated code cells for LSP server indexing)
```

### Module Layout

| Module | Responsibility |
|---|---|
| `ejn-core.el` | EIEIO data model (`ejn-notebook`, `ejn-cell` classes), notebook load/save, shadow file I/O |
| `ejn-cell.el` | Cell buffer lifecycle, insert/move/kill/split/merge/copy/yank, structural undo hooks |
| `ejn-master.el` | Polymode master view buffer with chunk delimiters, lazy cell initialization on scroll |
| `ejn-network.el` | Jupyter kernel lifecycle, ZMQ communication via `jupyter.el`, IOPUB message dispatch, output rendering |
| `ejn-lsp.el` | Composite file generation, LSP virtual buffer registration, bidirectional position mapping, jump-to-definition |
| `ejn-ui.el` | Cell header decoration, display margins, global undo records, markdown cell rendering |

### Key Design Decisions

- **Shadow Files**: Each cell writes to a real `.py`/`.md`/`.raw` file under `.ejn-cache/`, so LSP clients see proper files on disk
- **Composite File**: All code cells are concatenated with sentinel markers (`# ejn:cell:N`) into `composite.py` for cross-cell LSP features (jump-to-definition, completion)
- **Lazy Loading**: Cell buffers, shadow files, and LSP connections are created only when a cell scrolls into the visible window
- **Global Undo**: A single undo stack per notebook coalesces rapid keystrokes and spans cell boundaries
- **Text Properties over Overlays**: Cell decorations use `before-string` and `display-margin` text properties instead of the fragile overlay-based approach of EIN

## Requirements

- **Emacs 30.1+** (lexical-binding, EIEIO, Polymode support)
- **Jupyter** installed and available on `$PATH` (provides `jupyter kernelspec` and kernel processes)
- **Emacs packages**: `jupyter`, `polymode`, `lsp-mode`, `dash`, `s`, `f`

## Installation

### Prerequisites

Make sure you have Jupyter installed:

```bash
pip install jupyter
```

And a kernel for your language (e.g., Python):

```bash
pip install ipykernel
python -m ipykernel install --user --name python3 --display-name "Python 3"
```

### Option A: Eask (Recommended for Development)

[Eask](https://github.com/quickly-easy/eask) is the Emacs package manager used in this project:

```bash
# 1. Clone the repository
git clone https://github.com/emacs-jupyter-notebook/emacs-jupyter-notebook.git
cd emacs-jupyter-notebook

# 2. Install Eask (if not already installed)
# Follow instructions at https://github.com/quickly-easy/eask

# 3. Install dependencies
make install

# 4. Add to your Emacs init file
# See "Manual Setup" below for the elisp configuration
```

### Option B: Straight.el

```elisp
(straight-use-package
 '(ejn :type git :host github
       :repo "emacs-jupyter-notebook/emacs-jupyter-notebook"
       :files (:defaults "lisp/*.el")))
```

### Option C: Manual Setup

Add the following to your Emacs init file (`~/.emacs` or `~/.config/emacs/init.el`):

```elisp
;; Add EJN to load-path
(add-to-list 'load-path "/path/to/emacs-jupyter-notebook")
(add-to-list 'load-path "/path/to/emacs-jupyter-notebook/lisp")

;; Install dependencies via package.el
;; M-x package-install RET jupyter RET
;; M-x package-install RET polymode RET
;; M-x package-install RET lsp-mode RET
;; M-x package-install RET dash RET
;; M-x package-install RET s RET
;; M-x package-install RET f RET

;; Load EJN
(require 'ejn)
```

### Option D: Use Package

```bash
# Build the tar
eask build package

# Install
emacs -q -batch -L install/ -f package-install-file install/ejn-0.1.0.tar
```

## Usage

### Step 1: Open a Notebook

```
M-x ejn-open-file
```

You will be prompted for a `.ipynb` file path. EJN will:
1. Parse the notebook JSON into EIEIO objects
2. Create a Polymode master view buffer showing all cells
3. Lazily initialize the first cell's buffer, shadow file, and LSP connection

### Step 2: Start a Kernel

```
C-c C-S-k    (ejn:notebook-start-kernel)
```

You will be presented with a list of available kernelspecs. Select one (e.g., `python3`). A Jupyter kernel process starts, and the mode-line updates to show kernel status (e.g., `EJN [python | ●idle]`).

### Step 3: Edit and Execute Cells

Navigate between cells:
```
C-<down> / C-c C-n    Next cell
C-<up>   / C-c C-p    Previous cell
```

You can either:
- **Edit in the cell buffer**: Navigate to a cell and edit in its dedicated buffer
- **Edit in the master view**: The Polymode master view allows inline editing with syntax highlighting

Execute the current cell:
```
C-c C-c              Execute current cell
M-return             Execute and go to next cell
M-S-return           Execute and insert new cell below
C-c C-c (with C-u)   Execute all code cells
```

### Step 4: Manage Cell Structure

```
C-c C-a              Insert cell above
C-c C-b              Insert cell below
C-c <down>           Move cell down
C-c <up>             Move cell up
C-c C-k              Kill (delete) current cell
C-c C-s              Split cell at point
C-c RET              Merge cell with cell below
C-c M-w              Copy cell to kill ring
C-c C-w              Cut cell to kill ring
C-c C-y              Yank cell from kill ring
C-c C-t              Toggle cell type (code ↔ markdown)
C-c C-u              Change cell type (code/markdown/raw)
```

### Step 5: Manage Output

```
C-c C-e              Toggle output visibility for current cell
C-c C-l              Clear output of current cell
C-c C-S-l            Clear output of all cells
C-c C-v              Propagate output visibility to all cells
```

### Step 6: Use LSP Features

EJN automatically sets up LSP for code cells via shadow files. Use:

```
M-.                  Jump to definition (translates to composite file, resolves back to cell buffer)
M-,                  Jump back
```

Tab completion and inline diagnostics are provided by `lsp-mode` on the cell buffers.

### Step 7: Save and Close

```
C-x C-s              Save notebook to .ipynb
C-x C-w              Rename notebook file
C-c C-#              Close notebook (kernel stays alive)
C-c C-q              Kill kernel and close notebook
```

### Advanced: Kernel Management

```
C-c C-r              Reconnect to kernel
C-c C-z              Interrupt running kernel
C-c C-x C-r          Restart kernel (prompts to re-execute all cells)
C-c C-$              Show last kernel traceback
C-c C-/              Open scratch cell (transient, not persisted)
C-c C-;              Show current cell's output in dedicated buffer
```

### Advanced: Global Undo

EJN provides a notebook-wide undo system:

```
M-x ejn-global-undo  Undo the last change (content or structural)
```

Unlike standard Emacs undo, this works across cell boundaries. Editing in Cell A, then Cell B, then calling global undo will revert the Cell B change first.

## Keybindings Reference

| Key | Command | Description |
|---|---|---|
| `C-<down>` / `C-c C-n` | `goto-next-input` | Navigate to next cell |
| `C-<up>` / `C-c C-p` | `goto-prev-input` | Navigate to previous cell |
| `C-c C-a` | `insert-cell-above` | Insert new cell above |
| `C-c C-b` | `insert-cell-below` | Insert new cell below |
| `C-c <down>` | `move-cell-down` | Move cell down one position |
| `C-c <up>` | `move-cell-up` | Move cell up one position |
| `C-c C-k` | `kill-cell` | Delete current cell |
| `C-c C-s` | `split-cell-at-point` | Split cell at cursor |
| `C-c RET` | `merge-cell` | Merge with cell below |
| `C-c C-c` | `execute-cell` | Execute current cell |
| `M-return` | `execute-and-goto-next` | Execute and move to next |
| `M-S-return` | `execute-and-insert-below` | Execute and insert new cell |
| `C-c C-e` | `toggle-output` | Toggle output visibility |
| `C-c C-l` | `clear-output` | Clear cell output |
| `C-c C-S-l` | `clear-all-output` | Clear all outputs |
| `C-c C-t` | `toggle-cell-type` | Toggle code ↔ markdown |
| `C-c C-u` | `change-cell-type` | Change to code/markdown/raw |
| `C-x C-s` | `save-notebook` | Save to .ipynb |
| `C-x C-w` | `rename-notebook` | Rename notebook file |
| `C-c C-S-k` | `start-kernel` | Start a Jupyter kernel |
| `C-c C-r` | `reconnect-session` | Reconnect to kernel |
| `C-c C-z` | `kernel-interrupt` | Interrupt running kernel |
| `C-c C-x C-r` | `restart-session` | Restart kernel |
| `C-c C-#` | `close-notebook` | Close (kernel stays alive) |
| `C-c C-q` | `kill-kernel-and-close` | Kill kernel and close |
| `M-.` | `jump-to-source` | Jump to definition (LSP) |
| `M-,` | `jump-back` | Jump back from LSP navigation |
| `C-c C-$` | `tb-show` | Show last traceback |
| `C-c C-/` | `scratchsheet-open` | Open transient scratch cell |

## Cache Directory

EJN creates a `.ejn-cache/<notebook-stem>/` directory next to each `.ipynb` file. This directory contains:

- `cell_000.py`, `cell_001.py`, ... — shadow files for code cells
- `cell_000.md`, ... — shadow files for markdown cells
- `composite.py` — concatenated code cells for LSP indexing
- `scratch.py` — transient scratch cell file

The cache directory is gitignored and can be safely deleted (it will be regenerated on next open).

## Troubleshooting

**"No Jupyter kernelspecs found"**: Install `jupyter` and at least one kernel (`pip install ipykernel`, then `python -m ipykernel install --user`).

**LSP not providing completions**: Ensure `lsp-mode` is installed and a Python language server is available (e.g., `pip install pylsp` or `pyright`). The composite file is regenerated on a 0.3s debounce after each edit.

**Kernel shows "dead"**: The kernel process may have crashed. Use `C-c C-S-k` to start a new kernel, or `C-c C-r` to reconnect if the process is still running.

**"No cell at point" error**: Make sure you're in either a cell buffer or the master view buffer. The error appears if you try to run a cell command from an unrelated buffer.

## License

GNU GPL v3. See [LICENSE](LICENSE) for details.
