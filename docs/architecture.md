This report outlines the technical architecture of **EJN (Emacs Jupyter Notebook)**, a next-generation package designed to replace the aging **EIN (Emacs IPython Notebook)**. The primary goal is to resolve the long-standing incompatibility between Jupyter Notebooks in Emacs and the **Language Server Protocol (LSP)**.

## 1. Core Problem: The "Original Sin" of EIN
The older EIN uses a single buffer with many "overlays" to separate cells. This confuses LSP clients (like `lsp-mode` or `eglot`), which require distinct files and buffers to provide features like code completion, static analysis, and "jump to definition."

## 2. The EJN Solution: "One Cell, One Buffer"
EJN adopts a **Shadow File** strategy to satisfy modern development tools:
* **Virtual Mapping:** Each code cell is treated as an individual buffer linked to a physical "shadow file" (e.g., `cell_001.py`) stored in a hidden cache.
* **Composite View:** To handle dependencies between cells (e.g., a variable defined in Cell A used in Cell B), EJN creates a single, hidden "composite file" containing all cells. The LSP server indexes this file, while EJN maps the user's cursor position back and forth in real-time.

---

## 3. Key Technical Pillars
| Component | Implementation Strategy |
| :--- | :--- |
| **Data Model** | Uses **EIEIO** (object-oriented Emacs Lisp) to manage notebooks and cells as distinct objects. |
| **LSP Integration** | Utilizes the `lsp-virtual-buffer` API to provide full IDE intelligence within a notebook. |
| **Rendering** | Replaces buggy overlays with **text properties** and **margin areas** for a cleaner UI that doesn't flicker or crash. |
| **Communication** | Built on **jupyter.el**, using ZMQ for high-performance, asynchronous communication with the Jupyter kernel. |
| **Multi-mode Support** | Uses **Polymode** to allow Markdown and Code cells to coexist with proper syntax highlighting. |

---

## 4. Enhanced User Experience
EJN aims to keep the best parts of EIN while adding modern stability:
* **Global Undo:** Unlike standard Emacs (where undo is per-buffer), EJN tracks changes across the entire notebook, allowing users to undo actions chronologically across different cells.
* **Hybrid Completion:** Combines **LSP results** (static logic/types) with **Kernel results** (runtime data like Pandas column names) for superior accuracy.
* **Lazy Loading:** Large notebooks load instantly by only initializing buffers and LSP connections when a cell becomes visible.

## 5. Summary Comparison
| Feature | EIN (Old) | EJN (New) |
| :--- | :--- | :--- |
| **Architecture** | Single buffer / Overlays | 1-Cell-1-Buffer / Shadow files |
| **LSP Support** | Broken/None | Native & Full |
| **UI Stability** | High risk of conflicts | High (Text property-based) |
| **Undo System** | Per-cell only | Notebook-wide (Global) |

### Conclusion
EJN moves away from custom, fragile UI logic and instead integrates proven tools (`lsp-mode`, `polymode`, `jupyter.el`). By fixing the "Original Sin" of EIN, it offers a data science environment that retains the flexibility of Emacs while matching the intelligence of modern IDEs.
