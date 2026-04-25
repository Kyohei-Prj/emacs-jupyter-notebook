This roadmap is designed to move from a structural skeleton to a fully integrated IDE experience. By the end of each phase, you will have a "runnable" artifact that validates the core assumptions of your architecture.

---

## Phase 1: Scaffolding & Environment (The Skeleton)
**Goal:** Establish the project's physical presence and automated workflow. No logic is implemented here, only the "containers."

* **Project Initialization:**
    * Create the directory tree: `lisp/`, `test/`, and `.ejn-cache/` (initial gitignore).
    * Finalize the `Eask` file with all dependencies (`dash`, `s`, `f`, `jupyter`, `polymode`).
* **Template Files:**
    * `ejn.el`: Main entry point with package headers.
    * `ejn-core.el`: EIEIO class definitions for `ejn-notebook` and `ejn-cell`.
    * `ejn-network.el`: Wrappers for `jupyter.el` connections.
    * `ejn-lsp.el`: Logic for shadow file generation and `lsp-mode` integration.
* **CI/CD Setup:**
    * Configure GitHub Actions to run `eask lint` and `eask compile` on every push.
    * Create a `Makefile` for local convenience (`make install`, `make test`).

---

## Phase 2: Buffer-Cell Mapping & Virtual File System
**Goal:** Create a working prototype that can open a `.ipynb` file and split it into individual, editable buffers.

* **JSON Parser:** Implement the loader using the native `json-serialize` to populate EIEIO objects.
* **The Shadow Layer:** * Implement the "Shadow File" generator that writes code cells to `.ejn-cache/cell_N.py`.
    * Implement `after-change-functions` to sync buffer changes back to the EIEIO objects.
* **Basic Master View:** A simple buffer that uses `button.el` or `insert-text-button` to "open" specific cell buffers.
* **Prototype Deliverable:** An Emacs command `ejn-open-file` that opens a Jupyter Notebook and allows you to edit cells in independent buffers that stay in sync with the EIEIO model.

---

## Phase 3: LSP Integration (The Intelligence Layer)
**Goal:** Enable full code intelligence (completion, jump-to-definition) within cell buffers.

* **Virtual Buffer Logic:**
    * Implement the `ejn-lsp-composite-file` which merges all code cells into one hidden file.
    * Configure `lsp-virtual-buffer-mappings` to translate cursor positions between the cell buffer and the composite shadow file.
* **LSP Attachment:** * Automatically trigger `lsp` or `eglot` when a cell buffer is created.
    * Ensure the `project-root` is correctly identified so the LSP server sees the whole workspace.
* **Prototype Deliverable:** Opening a cell buffer and having `company-mode` or `corfu` provide suggestions based on variables defined in *other* cells of the same notebook.



---

## Phase 4: Communication & Execution
**Goal:** Connect to a live Jupyter kernel and execute code.

* **Kernel Management:**
    * Implement `ejn-kernel-start` to initialize a ZMQ connection via `jupyter.el`.
    * Create a "Manager" that tracks kernel status (Idle/Busy).
* **Execution Pipeline:**
    * Send cell content to the kernel and handle `iopub` messages.
    * Route stdout/stderr back to a dedicated "output area" in the cell buffer.
* **Output Rendering:**
    * Basic text output and image (PNG/SVG) rendering using `display` properties at the bottom of cell buffers.
* **Prototype Deliverable:** A `C-c C-c` command that runs the current cell and displays the result (including plots) directly below the code.

---

## Phase 5: UI Refinement & Global UX
**Goal:** Move away from raw buffers into a cohesive "Notebook UI" and solve the Undo problem.

* **Visual Polish:**
    * Replace standard headers with `before-string` overlays or text properties for a "clean" cell look.
    * Implement the side-margin indicators for execution count (`In [1]:`).
* **Global Undo Manager:**
    * Implement the centralized stack that tracks changes across all cell buffers to provide a linear undo experience.
* **Polymode Integration:** * Finalize the "Master View" where Markdown cells and Code cells coexist seamlessly using `polymode`.
* **Final Prototype:** A fully functional, visual notebook experience that feels like a modern IDE but retains Emacs's text-centric power.

---

## Summary of Milestones

| Phase | Working Prototype Capability |
| :--- | :--- |
| **Phase 2** | Opening/Editing/Saving `.ipynb` files via multiple buffers. |
| **Phase 3** | Code completion and "Jump to Definition" working across cells. |
| **Phase 4** | Executing code and seeing images/plots inside Emacs. |
| **Phase 5** | Production-ready UI with global Undo and stable multi-mode support. |
