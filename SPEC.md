# Phase 2 — Data Model and `.ipynb` I/O

## Goal

Define the in-memory data structures that represent a Jupyter notebook and its cells, and implement round-trip `.ipynb` (nbformat 4) parsing and serialization. This is pure data — no buffers, no kernels, no UI. Every change to notebook content flows through these structs.

## Features

1. Define `ejn-cell` struct — `cl-defstruct` with slots `id`, `type`, `language`, `source`, `outputs`, `execution-count`, `metadata`. Public constructor `ejn-make-cell` and predicate `ejn-cell-p`. All slots accessible via `cl-struct`-generated accessor functions.

2. Define `ejn-output` struct — `cl-defstruct` with slots `output-type`, `data`, `metadata`, `text`, `name`, `ename`, `evalue`, `traceback`. All slots accessible via accessor functions.

3. Define `ejn-notebook` struct — `cl-defstruct` with slots `path`, `nbformat`, `nbformat-minor`, `metadata`, `kernel-name`, `language`, `cells`, `dirty-p`. All slots accessible via accessor functions.

4. Parse `.ipynb` files — `ejn-io-read PATH` reads a file, validates `nbformat == 4`, constructs and returns an `ejn-notebook` struct. Unknown metadata keys are preserved in the passthrough `metadata` hash-table. Cell source arrays are joined into a single string.

5. Serialize `.ipynb` files — `ejn-io-write NOTEBOOK PATH` converts an `ejn-notebook` struct to JSON-serializable structure, splits `source` strings into line arrays, writes with 2-space indentation. Sets `dirty-p` to `nil` after write.

6. Cell manipulation helpers — five functions on `ejn-notebook` structs that return new structs without mutation: `ejn-notebook-insert-cell` (insert at index), `ejn-notebook-delete-cell` (remove by UUID), `ejn-notebook-move-cell` (swap adjacent by `'up`/`'down`), `ejn-notebook-cell-by-id` (lookup by UUID), `ejn-notebook-update-cell-source` (update source, set `dirty-p` to `t`).

7. Test data model — ERT tests in `ejn-data-test.el` covering struct construction, slot access, all five cell manipulation helpers including edge cases (insert at 0, insert at end, delete only cell, move first cell up, move last cell down).

8. Test `.ipynb` I/O — ERT tests in `ejn-io-test.el` covering `ejn-io-read` against three fixtures (`simple.ipynb`, `mixed-lang.ipynb`, `with-outputs.ipynb`), `ejn-io-write` serialization, and the round-trip invariant (read → write to temp → read → compare).

## Out of scope

- Kernel communication (Phase 3)
- Cell buffer / indirect buffer management (Phase 4)
- LSP integration (Phase 5)
- Shadow buffer for cross-cell LSP (Phase 6)
- Display layer / ewoc UI (Phase 7)
- Tree-sitter integration (Phase 8)
- Output rendering in the editor (Phase 9)
- Any user-facing commands or key bindings

## Architecture

### Data model

**`ejn-cell`** (created via `ejn-make-cell`):

| Slot | Type | Constraints | Default |
|------|------|-------------|---------|
| `id` | string | 36-char hyphenated UUID (8-4-4-4-12) | — (required) |
| `type` | symbol | `'code`, `'markdown`, or `'raw` | `'code` |
| `language` | string | Kernel language for code cells; `"markdown"` for markdown; `"raw"` for raw | `"python"` |
| `source` | string | Raw cell source text (may contain newlines) | `""` |
| `outputs` | list | Ordered list of `ejn-output` structs | `nil` |
| `execution-count` | integer or nil | Jupyter execution counter | `nil` |
| `metadata` | hash-table | `:test 'equal` — passthrough, preserves unknown keys | new empty hash-table |

**`ejn-output`**:

| Slot | Type | Constraints | Default |
|------|------|-------------|---------|
| `output-type` | symbol | `'stream`, `'display_data`, `'execute_result`, or `'error` | — (required) |
| `data` | hash-table | `:test 'equal` — MIME-type → content map | new empty hash-table |
| `metadata` | hash-table | `:test 'equal` — output metadata passthrough | new empty hash-table |
| `text` | string or nil | Convenience slot for `'stream` output body | `nil` |
| `name` | string or nil | Stream name: `"stdout"` or `"stderr"` | `nil` |
| `ename` | string or nil | Error name (e.g., `"NameError"`) | `nil` |
| `evalue` | string or nil | Error value / message | `nil` |
| `traceback` | string or nil | Full traceback as single string | `nil` |

**`ejn-notebook`** (created via `ejn-make-notebook`):

| Slot | Type | Constraints | Default |
|------|------|-------------|---------|
| `path` | string | Absolute path to `.ipynb` file on disk | `""` |
| `nbformat` | integer | Must be 4 for supported notebooks | `4` |
| `nbformat-minor` | integer | Sub-version (0–5) | `5` |
| `metadata` | hash-table | `:test 'equal` — top-level notebook metadata | new empty hash-table |
| `kernel-name` | string | e.g., `"python3"` | `""` |
| `language` | string | Primary kernel language, e.g., `"python"` | `""` |
| `cells` | list | Ordered list of `ejn-cell` structs | `nil` |
| `dirty-p` | boolean | Non-nil when unsaved changes exist | `nil` |

### Interface contracts

**`ejn-make-cell` & `&key id type language source outputs execution-count metadata`** → `ejn-cell`

- Required argument: `id` (string). All others optional with defaults from data model table.
- Returns an `ejn-cell` struct. Does not validate UUID format (parsers enforce it).
- `metadata` defaults to a new empty hash-table (never `nil` or shared).

**`ejn-make-notebook` &key path nbformat nbformat-minor metadata kernel-name language cells dirty-p** → `ejn-notebook`

- No required arguments. All have defaults from data model table.
- `metadata` and all per-cell `metadata` slots default to new empty hash-tables.

**`ejn-io-read` path** → `ejn-notebook`

- `path`: string, absolute or relative path to `.ipynb` file.
- Errors with `(error "Unsupported nbformat: %s" version)` if `nbformat != 4`.
- Errors with `(error "File not found: %s" path)` if file does not exist.
- Errors with `(error "Invalid JSON: %s" error-message)` if file content is not valid JSON.
- Joins `"source"` array (nbformat convention) into a single string via `(mapconcat #'identity source-array "\n")`.
- Preserves all known and unknown keys from `"metadata"` hash-tables.

**`ejn-io--parse-cell` raw-cell** → `ejn-cell`

- Private helper. Dispatches on `raw-cell["cell_type"]`.
- `"code"`: maps `"language"` from cell metadata or falls back to `"python"`.
- `"markdown"`: sets `language` to `"markdown"`.
- `"raw"`: sets `language` to `"raw"`.
- `"source"` is always joined to a single string regardless of type.
- `"id"` is required; errors with `(error "Cell missing required 'id' field")` if absent.

**`ejn-io--parse-output` raw-output** → `ejn-output`

- Private helper. Maps `"output_type"` → `output-type` symbol.
- `"stream"`: reads `"name"` → `name`, `"text"` → `text` (joined array if array).
- `"display_data"`: reads `"data"` hash-table → `data`.
- `"execute_result"`: reads `"data"` → `data`, `"execution_count"` → `execution-count` (stored in cell, not output).
- `"error"`: reads `"ename"` → `ename`, `"evalue"` → `evalue`, `"traceback"` → `traceback` (joined array if array).
- Preserves all unknown keys in `"metadata"`.

**`ejn-io-write` notebook path**

- `notebook`: `ejn-notebook` struct. `path`: string, destination path.
- Converts to nested hash-tables/lists matching nbformat 4 schema.
- Splits `source` strings into arrays of lines using `(split-string source "\n" t)`.
- Writes with `(json-encode ...)` to `path` with 2-space indent: `(format "%s\n" (json-encode obj))`.
- Sets `(setf (ejn-notebook-dirty-p notebook) nil)` after successful write.
- Errors with `(error "Cannot write to read-only file: %s" path)` if file exists and is not writable.

**`ejn-notebook-insert-cell` notebook cell index** → `ejn-notebook`

- Returns a new notebook with `cell` inserted at position `index` in the `cells` list.
- `index` 0 → prepend. `index` ≥ length → append.
- Sets `dirty-p` to `t` on the returned notebook.
- Errors with `(error "Cell index out of range: %d" index)` if `index < 0`.

**`ejn-notebook-delete-cell` notebook uuid** → `ejn-notebook`

- Returns a new notebook with the cell matching `uuid` removed.
- If no cell matches, returns a copy of the original notebook (no-op, no error).
- Sets `dirty-p` to `t` on the returned notebook.

**`ejn-notebook-move-cell` notebook uuid direction** → `ejn-notebook`

- `direction`: `'up` or `'down`.
- Returns a new notebook with the cell at `uuid` swapped with its neighbor in the given direction.
- If cell is first and `direction` is `'up`, or last and `direction` is `'down`, returns a copy unchanged (no error, no error).
- Sets `dirty-p` to `t` on the returned notebook.

**`ejn-notebook-cell-by-id` notebook uuid** → `ejn-cell` or `nil`

- Returns the first `ejn-cell` whose `id` slot equals `uuid`, or `nil` if not found.
- No side effects.

**`ejn-notebook-update-cell-source` notebook uuid new-source** → `ejn-notebook`

- Returns a new notebook with the cell matching `uuid` having its `source` replaced by `new-source`.
- If no cell matches, returns a copy of the original notebook unchanged.
- Sets `dirty-p` to `t` on the returned notebook.

### Tech stack

- Emacs 29.1+ built-in `cl-lib` → `cl-defstruct` for data types
- Emacs 29.1+ built-in `json` → `json-parse-string` and `json-encode` for serialization
- Emacs 29.1+ built-in `subr` → `make-hash-table`, `file-contents`, `split-string`, `mapconcat`
- `dash` (Phase 1 dependency, not yet used by Phase 2)
- `buttercup` + `el-mock` (dev-only, loaded optionally by test-helper)

### Non-goals

- Immutable data semantics beyond returning new structs (no persistent data structures)
- Cell validation beyond nbformat presence checks
- Notebook diffing or patch operations
- Incremental file writes (full re-serialize on every save)
- Support for nbformat 3 or nbformat 5

## Current phase

### Phase 2 — Data Model and `.ipynb` I/O

- [x] P2-T1 Define `ejn-cell` struct with slots, `ejn-make-cell` constructor, `ejn-cell-p` predicate [smoke] ✅
- [x] P2-T2 Define `ejn-output` struct with slots including `ename`, `evalue`, `traceback` for error outputs [smoke] ✅
- [x] P2-T3 Define `ejn-notebook` struct with slots and `ejn-make-notebook` constructor [smoke] ✅
- [x] P2-T4 Implement `ejn-io--parse-output` helper — maps raw JSON output dict to `ejn-output` struct; `'error` type populates `ename`/`evalue`/`traceback` slots [tdd] ✅
- [x] P2-T5 Implement `ejn-io--parse-cell` helper — maps raw JSON cell dict to `ejn-cell` struct [tdd] ✅
- [x] P2-T6 Implement `ejn-io-read` — full parser with nbformat validation, file reading, JSON parsing, and `ejn-notebook` construction [tdd] ✅
- [x] P2-T7 Implement `ejn-io-write` — serializer that converts `ejn-notebook` to JSON, splits source to line arrays, writes with 2-space indent [tdd] ✅
- [x] P2-T8 Implement `ejn-notebook-insert-cell` — returns new notebook with cell inserted at index [tdd] ✅
- [x] P2-T9 Implement `ejn-notebook-delete-cell` — returns new notebook with cell removed by UUID [tdd] ✅
- [x] P2-T10 Implement `ejn-notebook-move-cell` — returns new notebook with cell swapped in given direction [tdd] ✅
- [x] P2-T11 Implement `ejn-notebook-cell-by-id` — lookup cell by UUID in notebook [smoke] ✅
- [x] P2-T12 Implement `ejn-notebook-update-cell-source` — returns new notebook with source replaced and `dirty-p` set [tdd] ✅
- [x] P2-T13 Write tests for `ejn-cell`, `ejn-output`, `ejn-notebook` construction and slot access [tdd] ✅
- [x] P2-T14 Write `ejn-io-read` tests against all three fixtures — verify cell counts, UUIDs, source text, kernel-name, cell types, output struct construction [tdd] ✅
- [x] P2-T15 Write `ejn-io` round-trip test — read fixture, write to temp path via `ejn-test--with-temp-notebook`, re-read, compare cell UUIDs and source text [tdd] ✅
- [x] P2-T16 Write `ejn-io-read` error tests — unsupported nbformat, missing file, invalid JSON, cell missing `id` [tdd] ✅
- [x] P2-T17 Write cell manipulation tests — insert at 0, insert at end, delete existing/non-existing cell, move first/middle/last cell up/down [tdd] ✅

## Task list

### Phase 2 — Data Model and `.ipynb` I/O

(All tasks completed — see Current phase above.)

## Open questions

- [x] **Error output struct slots** — Resolved: added `ename`, `evalue`, `traceback` as optional slots to `ejn-output` (default `nil`). Only non-nil for `'error` outputs. The `ejn-io--parse-output` contract was updated to map error JSON fields directly to these slots.
- [x] **UUID v4 format** — Resolved: no change needed. Phase 1's `ejn--uuid` produces 36-char hyphenated strings sufficient for Phase 2. UUID format validation is deferred to Phase 10's error handling audit.
- [x] **`nbformat` validation strictness** — Resolved: accept any `nbformat == 4` (all 4.x sub-versions). Reject anything other than 4. The `nbformat-minor` value is preserved from the file without validation.
