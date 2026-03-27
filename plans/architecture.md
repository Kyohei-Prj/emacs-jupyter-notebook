**Goal:** Create an Emacs package called **Emacs-Jupyter-Notebook (EJN)** that emulates Jupyter Notebook functionality within Emacs, with LSP integration for code intelligence.

**Architecture context:**
- The package uses a cell-based notebook model (code cells, markdown cells, output areas) rendered in an Emacs buffer.
- Notebooks communicate with Jupyter kernels (via Jupyter protocol) for code execution.
- LSP integration provides jump-to-definition, completion, and diagnostics across notebook cells.
- The prefix `ejn:` is used for all commands.

**Complete target keymap — all bindings to be implemented across phases:**

```
Key                  Binding
──────────────────────────────────────────────────────────────────
C-<down>             ejn:worksheet-goto-next-input-km
C-<up>               ejn:worksheet-goto-prev-input-km
M-S-<return>         ejn:worksheet-execute-cell-and-insert-below-km
M-<down>             ejn:worksheet-not-move-cell-down-km
M-<up>               ejn:worksheet-not-move-cell-up-km

C-x C-s              ejn:notebook-save-notebook-command-km
C-x C-w              ejn:notebook-rename-command-km

M-RET                ejn:worksheet-execute-cell-and-goto-next-km
M-,                  ejn:pytools-jump-back-command
M-.                  ejn:pytools-jump-to-source-command

C-c C-a              ejn:worksheet-insert-cell-above-km
C-c C-b              ejn:worksheet-insert-cell-below-km
C-c C-c              ejn:worksheet-execute-cell-km
C-u C-c C-c          ejn:worksheet-execute-all-cells
C-c C-e              ejn:worksheet-toggle-output-km
C-c C-f              ejn:file-open-km
C-c C-k              ejn:worksheet-kill-cell-km
C-c C-l              ejn:worksheet-clear-output-km
C-c RET              ejn:worksheet-merge-cell-km
C-c C-n              ejn:worksheet-goto-next-input-km
C-c C-o              ejn:notebook-open-km
C-c C-p              ejn:worksheet-goto-prev-input-km
C-c C-q              ejn:notebook-kill-kernel-then-close-command-km
C-c C-r              ejn:notebook-reconnect-session-command-km
C-c C-s              ejn:worksheet-split-cell-at-point-km
C-c C-t              ejn:worksheet-toggle-cell-type-km
C-c C-u              ejn:worksheet-change-cell-type-km
C-c C-v              ejn:worksheet-set-output-visibility-all-km
C-c C-w              ejn:worksheet-copy-cell-km
C-c C-y              ejn:worksheet-yank-cell-km
C-c C-z              ejn:notebook-kernel-interrupt-command-km
C-c C-S-l            ejn:worksheet-clear-all-output-km
C-c C-#              ejn:notebook-close-km
C-c C-$              ejn:tb-show-km
C-c C-/              ejn:notebook-scratchsheet-open-km
C-c C-;              ejn:shared-output-show-code-cell-at-point-km
C-c <down>           ejn:worksheet-move-cell-down-km
C-c <up>             ejn:worksheet-move-cell-up-km
C-c C-x C-r          ejn:notebook-restart-session-command-km
C-c M-w              ejn:worksheet-copy-cell-km
```
