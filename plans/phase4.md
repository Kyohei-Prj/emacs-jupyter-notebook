## Phase 4 — Kernel Integration (Execution MVP)

This phase introduces **Jupyter kernel execution**, which is the first asynchronous, stateful subsystem. The key challenge is not just sending code, but **correctly implementing the Jupyter messaging lifecycle** in a way that integrates cleanly with your cell model.

We’ll decompose into **progressive layers**, so you can get a working execution loop early and refine it.

---

# 1. Process & Kernel Lifecycle (Local Kernel Boot)

---

### Task 4.1 — Decide execution backend strategy

**Goal:** Avoid premature complexity.

**Recommended (MVP)**

* Use `jupyter console` or `python -m ipykernel` subprocess
* Communicate via **ZMQ (preferred)** OR fallback:

  * stdin/stdout bridge (temporary, limited)

**Decision output**

* Document chosen approach:

  * `:zmq` (proper Jupyter protocol)
  * or `:stdio` (temporary MVP)

**Done when**

* You have a clear, fixed communication strategy

---

### Task 4.2 — Start kernel process

**Goal:** Launch a Jupyter kernel instance.

**Implement**

* `ejn--start-kernel`

**Behavior**

* Spawn process:

  * capture connection file (for ZMQ)
* Store:

  * process handle
  * connection info

**Done when**

* Kernel process is running and reachable

---

### Task 4.3 — Kernel state tracking

**Goal:** Avoid undefined states.

**Define states**

* `:starting`
* `:idle`
* `:busy`
* `:dead`

**Implement**

* `ejn--kernel-state`
* `ejn--set-kernel-state`

**Done when**

* State transitions are explicit and logged

---

# 2. Jupyter Messaging Layer (Core Protocol)

*(If using ZMQ — otherwise adapt for stdio MVP)*

---

### Task 4.4 — Connection file parsing

**Goal:** Extract ports and keys.

**Implement**

* `ejn--parse-connection-file`

**Extract**

* shell port
* iopub port
* stdin port
* control port
* signature key

**Done when**

* All channels can be addressed

---

### Task 4.5 — ZMQ socket setup

**Goal:** Establish communication channels.

**Channels**

* shell (REQ/REP)
* iopub (SUB)
* stdin (REQ/REP)

**Implement**

* `ejn--init-zmq-sockets`

**Done when**

* Sockets are open and connected

---

### Task 4.6 — Message construction

**Goal:** Generate valid Jupyter messages.

**Implement**

* `ejn--make-message`

**Fields**

* header
* parent_header
* metadata
* content

**Include**

* UUID message IDs
* session ID

**Done when**

* Messages match Jupyter protocol spec

---

### Task 4.7 — Message signing

**Goal:** Required for protocol compliance.

**Implement**

* HMAC signature using connection key

**Done when**

* Messages are accepted by kernel

---

### Task 4.8 — Send execute_request

**Goal:** Core execution trigger.

**Implement**

* `ejn--send-execute-request`

**Content**

```json id="z8gmnh"
{
  "code": "...",
  "silent": false,
  "store_history": true
}
```

**Done when**

* Kernel receives execution requests

---

# 3. Output Handling (IOPub Channel)

---

### Task 4.9 — IOPub listener loop

**Goal:** Receive asynchronous output.

**Implement**

* `ejn--start-iopub-listener`

**Behavior**

* Continuously read messages
* Dispatch by type

**Done when**

* Messages arrive and are parsed

---

### Task 4.10 — Message dispatcher

**Goal:** Route outputs correctly.

**Handle types**

* `stream` (stdout/stderr)
* `execute_result`
* `error`
* `status`

**Implement**

* `ejn--handle-iopub-message`

**Done when**

* Each message type triggers correct handler

---

### Task 4.11 — Associate output with cell

**Goal:** Correct attribution.

**Mechanism**

* Track `msg_id` per executing cell

**Implement**

* `ejn--execution-map`

  * msg_id → cell

**Done when**

* Output always appears in the correct cell

---

# 4. Output Rendering (MVP)

---

### Task 4.12 — Create output region

**Goal:** Display execution results.

**Implement**

* Separate overlay below cell:

  * `ejn--ensure-output-overlay`

**Done when**

* Each cell has a dedicated output area

---

### Task 4.13 — Render text output

**Goal:** Minimal viable display.

**Handle**

* stdout
* simple results

**Implement**

* `ejn--append-output`

**Done when**

* Output appears incrementally as kernel runs

---

### Task 4.14 — Clear previous output on execution

**Goal:** Match notebook behavior.

**Implement**

* `ejn--clear-output`

**Done when**

* Re-execution replaces old output

---

# 5. Execution Commands

---

### Task 4.15 — Execute current cell

**Command**

* `ejn:worksheet-execute-cell-km`

**Steps**

1. Get cell content
2. Clear output
3. Send execute_request
4. Mark cell as running

**Keybinding**

* `C-c C-c`

**Done when**

* Cell executes and displays output

---

### Task 4.16 — Execute and move to next

**Command**

* `ejn:worksheet-execute-cell-and-goto-next-km`

**Keybinding**

* `M-RET`

**Done when**

* Executes and cursor advances

---

# 6. Execution State Feedback

---

### Task 4.17 — Visual execution indicator

**Goal:** Show running status.

**Options**

* Overlay face change
* Mode-line indicator

**Done when**

* User can see when a cell is executing

---

### Task 4.18 — Handle kernel status messages

**Goal:** Track busy/idle transitions.

**Handle**

* `status: busy`
* `status: idle`

**Done when**

* State updates correctly on execution lifecycle

---

# 7. Error Handling (Minimal)

---

### Task 4.19 — Render errors

**Goal:** Show tracebacks.

**Handle**

* `error` message type

**Display**

* traceback text in output area

**Done when**

* Exceptions appear clearly

---

### Task 4.20 — Kernel crash detection

**Goal:** Avoid silent failure.

**Detect**

* process exit
* socket failure

**Done when**

* User is notified of dead kernel

---

# 8. Integration with Cell Model

---

### Task 4.21 — Extend cell struct

**Add**

```elisp id="kbz3cz"
(output-overlay
 execution-count
 last-msg-id)
```

**Done when**

* Cell stores execution metadata

---

### Task 4.22 — Ensure idempotent execution

**Goal:** Avoid duplicate outputs.

**Rules**

* Clear before run
* Ignore stale messages

**Done when**

* Re-running cell behaves predictably

---

# 9. Keymap Activation

Activate:

### Execution

* `C-c C-c` → execute cell
* `M-RET` → execute + next

---

# Phase 4 Final Acceptance Criteria

You are done when:

### Execution

* Can start a kernel automatically
* Execute a Python cell successfully

### Output

* stdout appears in correct cell
* Errors render properly

### Interaction

* Execution is non-blocking (async)
* Multiple executions do not corrupt state

### Stability

* Kernel state tracked correctly
* No message misrouting between cells

---

## Recommended Implementation Order (Critical Path)

1. **Kernel start (4.2)**
2. **Execute request (4.8)**
3. **Basic output (4.12–4.13)**
4. **IOPub listener (4.9–4.10)**
5. **Execution mapping (4.11)**

---

## Important Strategic Note

If you want to accelerate development:

* Start with a **“fake kernel” adapter**:

  * run Python via subprocess
  * capture stdout
* Then swap in full Jupyter protocol later

This dramatically reduces early complexity while preserving architecture.

---
