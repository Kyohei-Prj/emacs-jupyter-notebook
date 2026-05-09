# Phase 2 — Notebook Model and Persistence Design

Date: 2026-05-09
Phase: 2
Status: Approved

---

## Goal

Implement the notebook engine independent of UI: data model structs, `.ipynb` parsing and serialization, dirty tracking, and a transactional mutation system. All functionality must be testable without Emacs buffers or kernel connections.

---

## Architectural Decisions

### Persistence Abstraction: Full CLOS Generics

Following Phase 0 spec section 5.3, persistence uses `cl-defgeneric` with a backend registration system. The `.ipynb` backend is the sole initial implementation. This matches the kernel abstraction pattern and enables future remote/alternate backends without refactoring the model layer.

### Dirty Tracking: Full Transaction System

The transaction system (`ejn-with-transaction`, `ejn-with-undo-group`) and per-cell dirty tracker are implemented in Phase 2, not deferred to Phase 3. The model enforces transactional mutation patterns from day one, preventing UI/model coupling. Undo snapshots are model-level and buffer-agnostic.

### Implementation Approach: Layered Build Order

Files are implemented in dependency order with validation gates between layers:
1. Structs layer (cell, output, notebook structs)
2. Transaction layer (transaction macros, dirty tracker, cell management API)
3. Persistence layer (CLOS generics, backend registry, ipynb parser/serializer)

Each layer is byte-compiled, tested, and passes lint before proceeding.

---

## File Structure

```
lisp/
├── ejn-cell.el           ; ejn-cell and ejn-output structs, constructors
├── ejn-model.el          ; ejn-notebook struct, transaction system, dirty tracker, cell management
└── ejn-persistence.el    ; CLOS persistence generics, backend registry, ipynb parser/serializer

test/
├── ejn-cell-test.el
├── ejn-model-test.el
└── ejn-persistence-test.el

test/fixtures/
├── sample.ipynb          ; (existing) basic cells
├── empty.ipynb           ; minimal valid notebook
├── with-outputs.ipynb    ; notebook with various output types
└── unknown-metadata.ipynb ; notebook with custom metadata fields
```

`ejn-core.el` will gain `(require 'ejn-model)` to expose the model at package load.

---

## Structs Layer

### `ejn-cell.el`

Defines the leaf data structures. No dependencies on other EJN modules beyond `ejn-core`.

#### `ejn-output` (cl-defstruct)

| Field | Type | Description |
|---|---|---|
| `type` | keyword | One of: `'stream` \| `'display-data` \| `'execute-result` \| `'error` |
| `mime-data` | alist | MIME type strings mapped to content arrays (e.g. `(("text/plain" . ("42")))`). Matches nbformat JSON structure — keys are MIME types, values are arrays of strings. |
| `metadata` | alist | Arbitrary output-level metadata |
| `request-id` | string | Execution request ID for stale output detection |

Constructor: `ejn-make-output` — validates type enum, sets nil defaults.

#### `ejn-cell` (cl-defstruct)

| Field | Type | Description |
|---|---|---|
| `id` | string | Stable UUID (from .ipynb or generated) |
| `type` | keyword | One of: `'code` \| `'markdown` \| `'raw` |
| `source` | string | Editable cell content |
| `outputs` | list | List of `ejn-output` structs |
| `metadata` | alist | Arbitrary cell-level metadata |
| `execution-count` | integer \| nil | Kernel execution count |
| `execution-state` | keyword | One of: `'idle` \| `'queued` \| `'executing` \| `'streaming` \| `'completed` \| `'error` \| `'interrupted` |
| `execution-version` | integer | Monotonically increasing; defaults to 0 |

Constructor: `ejn-make-cell` — generates UUID via `random`, sets defaults (`source` = `""`, `outputs` = `nil`, `metadata` = `nil`, `execution-count` = `nil`, `execution-state` = `'idle`, `execution-version` = 0). Note: `metadata` defaults to `nil` (absent) rather than an empty alist, so that notebooks without cell metadata serialize cleanly.

UUID generation uses `(format "%08x-%04x-%04x-%04x-%012x" ...)` with `random` for simplicity. Not cryptographically secure, sufficient for local notebook editing.

---

## Transaction Layer

### `ejn-model.el`

Defines the notebook container, transaction system, dirty tracking, and cell management API. Depends on `ejn-cell`.

#### `ejn-notebook` (cl-defstruct)

| Field | Type | Description |
|---|---|---|
| `id` | string | Stable UUID |
| `path` | string \| nil | File path or nil for unsaved notebooks |
| `metadata` | alist | Notebook-level metadata (kernelspec, language_info, etc.) |
| `cells` | vector | Vector of `ejn-cell` structs |
| `dirty` | boolean | Overall dirty flag |
| `nbformat` | integer | Major nbformat version (e.g. 4) |
| `nbformat-minor` | integer | Minor nbformat version (e.g. 5) |
| `dirty-cells` | hash-table | Cell IDs marked dirty since last clean |
| `undo-history` | list | Stack of undo snapshots |

Constructor: `ejn-make-notebook` — generates UUID, initializes empty cells vector, dirty cell hash table, and undo history.

#### Transaction Macros

**`ejn-with-transaction`** notebook &rest body

Wraps model mutations. Before executing BODY, captures a snapshot of affected cells. After BODY, marks the notebook dirty. If BODY signals an error, the snapshot is restored.

```elisp
(ejn-with-transaction notebook
  (ejn-notebook-set-cell-source notebook cell-id new-source))
```

**`ejn-with-undo-group`** label notebook &rest body

Wraps `ejn-with-transaction` and records the before/after snapshot in the notebook's undo history with a user-facing label.

```elisp
(ejn-with-undo-group "Insert cell" notebook
  (ejn-notebook-insert-cell notebook 'code :at 0))
```

#### Dirty Tracker

Functions operating on `ejn-notebook-dirty-cells` hash table:

- `ejn-notebook-mark-dirty` NOTEBOOK CELL-ID — mark a cell as changed
- `ejn-notebook-clean-cell` NOTEBOOK CELL-ID — clear dirty flag for a cell
- `ejn-notebook-dirty-cells` NOTEBOOK — return list of dirty cell IDs
- `ejn-notebook-clean-all` NOTEBOOK — clear all dirty flags

#### Cell Management API

All cell mutations go through these functions (which internally use transactions):

- `ejn-notebook-insert-cell` NOTEBOOK TYPE &key at after — insert a new cell at index `at` or after cell ID `after`
- `ejn-notebook-delete-cell` NOTEBOOK CELL-ID — remove a cell by ID
- `ejn-notebook-set-cell-source` NOTEBOOK CELL-ID SOURCE — update cell source text
- `ejn-notebook-cell-by-id` NOTEBOOK CELL-ID — lookup cell by ID
- `ejn-notebook-cell-at-index` NOTEBOOK INDEX — lookup cell by position
- `ejn-notebook-cell-index` NOTEBOOK CELL-ID — get index of cell by ID

#### Undo API

- `ejn-undo` NOTEBOOK — pop and apply the latest undo snapshot
- `ejn-redo` NOTEBOOK — reapply an undone snapshot

Snapshots are stored as plists of per-cell mutable state (`id`, `source`, `outputs`, `execution-count`, `execution-state`, `execution-version`), one plist per cell in the notebook. This avoids deep-copying entire structs while capturing all fields that change during normal use. Immutable fields (`type`, `metadata`) are not snapshotted.

---

## Persistence Layer

### `ejn-persistence.el`

Implements the CLOS persistence backend API and the `.ipynb` reader/writer. Depends on `ejn-model` and `ejn-cell`.

#### CLOS Generics

```elisp
(cl-defgeneric ejn-persistence-read (backend path))
(cl-defgeneric ejn-persistence-write (backend notebook path))
(cl-defgeneric ejn-persistence-can-handle-p (backend path))
```

#### Backend Registry

- `ejn-register-persistence-backend` TYPE CONSTRUCTOR &key predicate — register a backend
- `ejn-persistence-backend-for` PATH — return best backend for a path, or nil
- Internal hash table maps predicates to backend constructors

The `.ipynb` backend is auto-registered at module load with predicate `(lambda (path) (string-suffix-p ".ipynb" path))`.

#### nbformat v4 Parser

- `ejn-ipynb-parse-notebook` PATH — read file, parse JSON, return `ejn-notebook`
- `ejn-ipynb-parse-cell` JSON-ALIST — convert JSON cell to `ejn-cell`
- `ejn-ipynb-parse-output` JSON-ALIST — convert JSON output to `ejn-output`

**Source field normalization:** nbformat v4 represents `source` as either a string or an array of strings (line segments). The parser always normalizes to a single concatenated string. When the source is an array, elements are joined without adding extra newlines (the array elements may or may not include trailing newlines — the parser joins them as-is).

**Metadata preservation:** All keys in notebook-level and cell-level metadata are preserved, including unrecognized ones. Metadata is stored as an alist, which naturally preserves arbitrary keys.

**MIME data preservation:** All MIME type keys in output `data` fields are preserved, including unrecognized types. Stored as an alist in `ejn-output.mime-data`, matching the nbformat JSON structure directly.

#### nbformat v4 Serializer

- `ejn-ipynb-serialize-notebook` NOTEBOOK — return JSON-serializable plist
- `ejn-ipynb-serialize-cell` CELL — return JSON-serializable plist
- `ejn-ipynb-serialize-output` OUTPUT — return JSON-serializable plist

**Source field output:** Serializer outputs `source` as a single string (nbformat v4.2+ compatible). This is the cleaner representation and is supported by all modern notebook readers.

**JSON output formatting:** Uses `json-pretty-print` for human-readable output. Output is written with UTF-8 coding system.

#### Convenience Functions

- `ejn-model-from-file` PATH — high-level load; dispatches to registered backend
- `ejn-model-to-file` NOTEBOOK PATH — high-level save; dispatches to registered backend

#### Error Conditions

- `ejn-invalid-notebook` — malformed JSON, missing required fields, corrupt structure
- `ejn-unsupported-format` — nbformat version not supported (currently only v4)

Errors include the file path and underlying error message for debugging.

---

## Testing Strategy

### `ejn-cell-test.el`

- Cell creation with each type produces correct defaults
- UUID generation produces unique IDs across multiple cells
- Output creation validates type enum
- Invalid output type signals error
- Execution version defaults to 0

### `ejn-model-test.el`

- Notebook creation sets correct defaults
- Cell insert at index and after existing cell
- Cell deletion updates vector correctly
- Cell source mutation
- `ejn-with-transaction` marks notebook dirty
- Transaction rollback on error restores pre-mutation state
- `ejn-with-undo-group` records snapshots in undo history
- `ejn-undo` restores previous state
- `ejn-redo` reapplies undone state
- Dirty tracker: mark, enumerate, clean individual cell, clean all
- Cell lookup by ID returns correct cell
- Cell lookup by index returns correct cell
- Insert and delete maintain ID-to-index mapping consistency

### `ejn-persistence-test.el`

- Parse `sample.ipynb` produces correct notebook/cell/output structs
- Parse `empty.ipynb` produces valid empty notebook
- Parse `with-outputs.ipynb` preserves all output types
- Parse `unknown-metadata.ipynb` preserves unknown metadata keys
- Serialize notebook produces valid nbformat v4 JSON
- Round-trip: load fixture -> save to temp file -> reload -> struct equality
- Round-trip with modification: load -> add cell -> save -> reload -> verify new cell
- Source field normalization: array-of-strings input -> single string in model -> single string output
- Malformed JSON signals `ejn-invalid-notebook`
- Unsupported nbformat version signals `ejn-unsupported-format`
- Backend registry dispatch: `.ipynb` files resolve to ipynb backend
- Non-.ipynb files return nil from `ejn-persistence-backend-for`

### Test Fixtures

| Fixture | Purpose |
|---|---|
| `sample.ipynb` | Basic code/markdown cells (existing) |
| `empty.ipynb` | Zero cells, minimal valid nbformat v4 |
| `with-outputs.ipynb` | All output types: stream, execute_result, error, display_data with multiple MIME types |
| `unknown-metadata.ipynb` | Custom notebook and cell metadata keys not defined by nbformat spec |

---

## Dependencies

No new external dependencies. Uses only:
- `cl-lib` — `cl-defstruct`, `cl-defgeneric`
- `json` — built-in JSON parsing/serialization
- `ejn-core` — existing core module
- `ejn-cell` — cell/output structs
- `ejn-model` — notebook model and transactions

---

## Out of Scope

- Buffer rendering (Phase 3)
- Kernel execution (Phase 4)
- Autosave (Phase 8 ecosystem integration)
- Remote notebook backends (future)
- Schema validation beyond nbformat version check
- nbformat v5 support (deferred)

---

## Finish Conditions

Notebook state can be:
- Loaded from `.ipynb` files
- Modified programmatically through the model API
- Serialized back to valid `.ipynb` files
- Round-tripped losslessly (metadata, cell IDs, MIME data preserved)
- Undo/redo applied to model mutations
- Tracked for dirty state per-cell

All without UI involvement.
