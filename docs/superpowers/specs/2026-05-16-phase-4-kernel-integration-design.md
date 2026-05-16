# Phase 4 — Kernel Runtime Integration Design

Date: 2026-05-16  
Status: Approved  
Depends on: Phase 2 (Model & Persistence), Phase 3 (Buffer Projection)

---

## Goals

Implement asynchronous kernel execution so that notebook cells can be evaluated against a live Jupyter kernel without blocking Emacs.

Specifically:
- Execute code cells against a Jupyter kernel via emacs-jupyter transport
- Route async outputs (stdout, stderr, results, errors) back to the correct cells
- Manage kernel lifecycle (start, restart, interrupt, shutdown) per notebook buffer
- Queue sequential execution requests when kernel is busy

---

## Architecture

### Module Structure

Phase 4 introduces three new modules:

| Module | Responsibility |
|--------|---------------|
| `ejn-kernel.el` | Kernel abstraction: CLOS generics, `ejn-kernel` struct, state machine |
| `ejn-kernel-jupyter.el` | Jupyter adapter: implements generics via emacs-jupyter |
| `ejn-execute.el` | Execution pipeline: queue, tracking, output routing, user commands |

Dependency flow:

```
ejn-execute.el  →  ejn-kernel.el  →  ejn-kernel-jupyter.el  →  emacs-jupyter
      ↑
      └──── model (ejn-model.el) + render (ejn-render.el)
```

### Kernel Abstraction (`ejn-kernel.el`)

Defines the kernel interface independent of transport.

**`ejn-kernel` struct:**
- `id` — unique kernel instance ID
- `state` — one of: `startup`, `connected`, `busy`, `interrupted`, `dead`
- `client` — opaque transport client (nil until connected)
- `kernelspec` — kernelspec name string

**CLOS generics:**
- `(ejn-kernel-execute kernel code request-id callbacks)` — send code for execution
- `(ejn-kernel-interrupt kernel)` — interrupt running computation
- `(ejn-kernel-restart kernel)` — restart the kernel process
- `(ejn-kernel-shutdown kernel)` — shutdown the kernel
- `(ejn-kernel-start kernel kernelspec)` — start a new kernel
- `(ejn-kernel-alive-p kernel)` — check if kernel is responsive

**Callbacks** passed to `ejn-kernel-execute` are a plist:
- `:on-stream` — called with (cell-id text output-name) for stream messages
- `:on-result` — called with (cell-id mime-data) for execute_result
- `:on-display` — called with (cell-id mime-data) for display_data
- `:on-error` — called with (cell-id ename evalue traceback) for error
- `:on-complete` — called with (cell-id status) on status=idle

### Jupyter Adapter (`ejn-kernel-jupyter.el`)

Implements `ejn-kernel` generics using emacs-jupyter transport.

**Client creation:**
- Calls `jupyter-client` with kernelspec name
- Calls `jupyter-connect` to establish I/O channels
- Stores `jupyter-kernel-client` in `ejn-kernel-client`

**Message handlers** via `define-jupyter-client-handler`:
- `jupyter-handle-stream` — extracts text and name, invokes `:on-stream` callback
- `jupyter-handle-execute-result` — extracts mime data, invokes `:on-result`
- `jupyter-handle-display-data` — extracts mime data, invokes `:on-display`
- `jupyter-handle-error` — extracts ename/evalue/traceback, invokes `:on-error`
- `jupyter-handle-status` — on `idle`, invokes `:on-complete`; on `error`, transitions to dead

Each handler extracts the parent message ID from `message.parent_header` to correlate with the originating request. The adapter maps request-id → callback plist to route messages to correct callbacks.

### Execution Pipeline (`ejn-execute.el`)

Owns the FIFO execution queue, cell state transitions, and user commands.

**Execution queue:**
- Per-kernel FIFO queue of pending requests
- Each request: `(cell-id, source, request-id, execution-version)`
- When kernel state is `connected`, immediately executes and transitions kernel to `busy`
- When kernel state is `busy`, enqueues and sets cell state to `queued`
- On `status=idle` from kernel, dequeues next request or transitions kernel back to `connected`

**Cell state machine:**

```
idle → queued → executing → streaming
                              → completed
                              → error
                              → interrupted
```

Transitions:
- `idle → queued`: cell enqueued while kernel busy
- `queued → executing`: request sent to kernel
- `executing → streaming`: first stream/result/display message received
- `streaming → completed`: status=idle received
- `streaming → error`: error message received
- `streaming → interrupted`: interrupt signal received
- All terminal states → `idle` on completion

**Output routing:**
- Each execute request gets a unique `request-id` (UUID)
- Cell's `execution-version` is incremented on each execution
- Adapter validates that incoming outputs match the cell's current `execution-version`
- Stale outputs (from superseded executions) are silently dropped
- Outputs are appended to `ejn-cell-outputs` list as `ejn-output` structs
- Cell is marked dirty after each output; `ejn-render-dirty-cells` handles incremental render

**User commands:**
- `ejn-execute-cell` — execute current cell
- `ejn-execute-cell-and-goto-next` — execute and move down
- `ejn-execute-all-above` — execute all cells above cursor sequentially
- `ejn-execute-all-below` — execute all cells below cursor sequentially
- `ejn-interrupt-kernel` — interrupt current execution
- `ejn-restart-kernel` — restart kernel
- `ejn-quit-kernel` — shutdown kernel
- `ejn-restart-kernel-and-run-all` — restart then execute all cells

Markdown and raw cells are no-ops for execution (signal informative message).

---

## Kernel Lifecycle

### Auto-Connect on Open

When `ejn-open` loads a notebook:
1. Read `notebook.metadata.kernelspec` from notebook model
2. Create `ejn-kernel` struct with kernelspec name
3. Call `ejn-kernel-start` to start kernel in background
4. Store kernel as buffer-local `ejn--kernel`
5. If kernelspec is missing from metadata, defer connection until first execution (prompt via `completing-read` over available kernelspecs)

### Buffer Lifecycle

Kernel is tied to buffer lifetime:
- `kill-buffer-hook` calls `ejn-kernel-shutdown` if kernel is alive
- Restart recreates the underlying jupyter client
- Interrupt drains queued requests, resets executing cell to `interrupted`

### Error States

| Scenario | Behavior |
|----------|---------|
| Kernel dies during execution | Cell → `error`, queue drained, user must restart |
| Connection fails on open | Buffer opens normally, execution signals `user-error` |
| Malformed kernel response | Caught in adapter, logged, cell → `error` |
| Buffer killed during execution | Hook shuts down kernel, cancels pending requests |

---

## Data Flow

Complete execution flow:

```
User presses Shift-Enter
  → ejn-execute-cell
    → get current cell via ejn-cell-at-point
    → increment cell execution-version
    → generate request-id (UUID)
    → construct callbacks plist → route to this cell
    → if kernel state is `connected`:
        set cell state = executing
        call ejn-kernel-execute(kernel, source, request-id, callbacks)
      else:
        set cell state = queued
        enqueue (cell-id, source, request-id, execution-version)
    → mark cell dirty → incremental render

  [async] kernel processes code
  [async] ioPub messages arrive
    → adapter handler extracts parent message ID
    → looks up request-id → callbacks
    → invokes callback with cell-id + data
      → callback validates execution-version
      → appends ejn-output to cell outputs
      → updates cell execution-state
      → marks cell dirty → incremental render

  [async] status=idle arrives
    → callback invoked with cell-id + "ok"/"error"
    → set cell state = completed/error
    → check queue:
        if non-empty: dequeue, set cell=executing, execute
        if empty: set kernel state = `connected`
```

---

## Testing Strategy

### Unit Tests (mock kernel, no emacs-jupyter)

- **Execution queue**: FIFO ordering, enqueue while busy, dequeue on idle
- **Output routing**: correct cell association, stale output rejection via execution-version
- **Cell state machine**: all valid transitions, invalid transitions rejected
- **Output accumulation**: stream chunks append in order, multiple output types coexist
- **Interrupt**: drains queue, resets cell state
- **Markdown cell execution**: returns no-op

### Integration Tests (with emacs-jupyter)

- Execute `print("hello")`, verify stdout in cell output
- Execute code that raises exception, verify error output with traceback
- Execute two cells in succession, verify sequential execution
- Interrupt running cell, verify state recovery
- Restart kernel, verify clean state

### Test Fixtures

- Notebook with code cells that produce known output
- Notebook with cells that produce errors
- Notebook with large streaming output

---

## Dependencies on Existing Code

| Module | Used API |
|--------|---------|
| `ejn-cell.el` | `ejn-cell-outputs`, `ejn-cell-execution-state`, `ejn-cell-execution-version`, `ejn-make-output` |
| `ejn-model.el` | `ejn-notebook-cell-by-id`, `ejn-notebook-mark-dirty` |
| `ejn-render.el` | `ejn-render-dirty-cells` (incremental render after output update) |
| `ejn-navigation.el` | `ejn-cell-at-point`, `ejn-cell-region` |
| `ejn-mode.el` | `ejn--notebook` buffer-local, `ejn--kernel` buffer-local |
| `ejn-mime.el` | MIME registry used by existing `ejn-render-outputs` |

---

## Out of Scope

- Completion/inspect (deferred to Phase 6 LSP integration)
- Kernel selection UI (user runs `M-x ejn-connect-to-kernel` if needed)
- Multi-kernel support (one kernel per notebook)
- Remote kernel connections (local kernels only for MVP)
