## Phase 6 — Kernel Lifecycle Management

Phase 6 turns your kernel integration from “works most of the time” into a **robust, recoverable system**. The emphasis is on:

* **State machine correctness**
* **Failure recovery**
* **User-controlled lifecycle operations**

You are essentially building a **process supervisor + connection manager**.

---

# 1. Kernel State Machine (Formalization)

---

### Task 6.1 — Define full kernel state model

**Goal:** Eliminate ambiguous transitions.

**States**

```elisp
:starting
:idle
:busy
:restarting
:interrupting
:dead
:disconnected
```

**Implement**

* `ejn--kernel-state`
* `ejn--set-kernel-state`
* `ejn--valid-transition-p`

**Done when**

* Invalid transitions are rejected/logged

---

### Task 6.2 — Centralize state transitions

**Goal:** Avoid scattered state mutation.

**Implement**

* `ejn--transition-kernel-state (new-state reason)`

**Done when**

* All state changes go through one function

---

# 2. Interrupt Kernel

---

### Task 6.3 — Implement interrupt signal

**Command**

* `ejn:notebook-kernel-interrupt-command-km`

**Strategies**

* Send SIGINT to process (local kernel)
* OR send Jupyter `interrupt_request` (ZMQ control channel)

**Keybinding**

* `C-c C-z`

**Done when**

* Running execution stops mid-cell

---

### Task 6.4 — Handle interrupt acknowledgement

**Goal:** Stabilize post-interrupt state.

**Behavior**

* Kernel should transition:

  * `:busy → :idle`

**Done when**

* Execution queue resumes or halts cleanly

---

### Task 6.5 — Clear pending execution queue on interrupt

**Goal:** Avoid unintended continuation.

**Implement**

* `ejn--clear-execution-queue`

**Done when**

* No further cells execute after interrupt

---

# 3. Restart Kernel

---

### Task 6.6 — Graceful kernel shutdown

**Goal:** Clean resource teardown.

**Implement**

* `ejn--shutdown-kernel`

**Steps**

* Close sockets
* Kill process
* Clean temp files

**Done when**

* No zombie processes remain

---

### Task 6.7 — Restart kernel command

**Command**

* `ejn:notebook-restart-session-command-km`

**Steps**

1. Shutdown kernel
2. Start new kernel
3. Reset execution state

**Keybinding**

* `C-c C-x C-r`

**Done when**

* New kernel replaces old one seamlessly

---

### Task 6.8 — Reset cell execution metadata

**Goal:** Reflect new session.

**Reset**

* execution count
* msg_id
* running state

**Done when**

* Notebook reflects fresh kernel state

---

# 4. Reconnect Session

---

### Task 6.9 — Detect disconnection

**Goal:** Recognize broken connections.

**Detect**

* socket failure
* timeout
* missing heartbeat (optional)

**Done when**

* Kernel marked `:disconnected`

---

### Task 6.10 — Reconnect to existing kernel

**Command**

* `ejn:notebook-reconnect-session-command-km`

**Steps**

1. Re-read connection file
2. Reinitialize sockets
3. Resubscribe to IOPub

**Keybinding**

* `C-c C-r`

**Done when**

* Output resumes without restarting kernel

---

### Task 6.11 — Rebuild execution mapping

**Goal:** Avoid orphaned outputs.

**Implement**

* Reset `msg_id → cell` map

**Done when**

* New executions map correctly

---

# 5. Kill Kernel & Close Notebook

---

### Task 6.12 — Combined shutdown + buffer close

**Command**

* `ejn:notebook-kill-kernel-then-close-command-km`

**Steps**

1. Shutdown kernel
2. Kill buffer
3. Cleanup resources

**Keybinding**

* `C-c C-q`

**Done when**

* No lingering processes or buffers

---

# 6. Heartbeat & Health Monitoring (Optional MVP+)

---

### Task 6.13 — Heartbeat channel (if using ZMQ)

**Goal:** Detect dead kernels quickly.

**Implement**

* Ping kernel periodically

**Done when**

* Missing heartbeat triggers state change

---

### Task 6.14 — Auto-mark kernel dead

**Goal:** Avoid silent failures.

**Trigger**

* heartbeat failure OR process exit

**Done when**

* UI reflects dead kernel immediately

---

# 7. Process Monitoring

---

### Task 6.15 — Attach process sentinel

**Goal:** React to process exit.

**Implement**

* Emacs process sentinel

**Done when**

* Kernel death triggers cleanup + notification

---

### Task 6.16 — Handle abnormal termination

**Goal:** Robust recovery.

**Behavior**

* Transition → `:dead`
* Notify user
* Offer restart

**Done when**

* User is never left in undefined state

---

# 8. Resource Cleanup Guarantees

---

### Task 6.17 — Ensure socket cleanup

**Goal:** Prevent descriptor leaks.

**Done when**

* No open sockets after shutdown

---

### Task 6.18 — Temp file management

**Goal:** Avoid filesystem clutter.

**Handle**

* connection files

**Done when**

* Files removed or reused safely

---

# 9. UX Feedback for Lifecycle Events

---

### Task 6.19 — User notifications

**Goal:** Make state visible.

**Use**

* `message`
* mode-line indicator

**Events**

* kernel started
* restarted
* interrupted
* dead

**Done when**

* User always knows kernel status

---

### Task 6.20 — Prevent invalid actions

**Goal:** Avoid user confusion.

**Examples**

* Cannot execute if:

  * kernel `:dead`
  * kernel `:starting`

**Done when**

* Commands fail gracefully with message

---

# 10. Integration with Execution System

---

### Task 6.21 — Pause execution queue during lifecycle ops

**Goal:** Avoid race conditions.

**Apply to**

* interrupt
* restart
* reconnect

**Done when**

* Queue never runs during unstable states

---

### Task 6.22 — Resume queue after recovery

**Goal:** Smooth continuation.

**Done when**

* Execution resumes only when safe

---

# 11. Keymap Activation

Activate:

### Kernel control

* `C-c C-z` → interrupt
* `C-c C-x C-r` → restart
* `C-c C-r` → reconnect
* `C-c C-q` → kill + close

---

# Phase 6 Final Acceptance Criteria

You are done when:

### Control

* Can interrupt long-running execution reliably
* Can restart kernel without restarting Emacs

### Recovery

* Can reconnect to existing kernel session
* Can recover from disconnections

### Stability

* No zombie processes
* No orphan sockets
* No stuck execution states

### UX

* Kernel state always visible
* Invalid actions prevented clearly

---

## Recommended Implementation Order

1. **State machine (6.1–6.2)** ← foundation
2. **Interrupt (6.3–6.5)**
3. **Restart (6.6–6.8)**
4. **Process sentinel (6.15–6.16)**
5. **Reconnect (6.9–6.11)**
6. **Cleanup guarantees (6.17–6.18)**

---

## Critical Design Insight

Phase 6 is where most notebook systems fail in practice.

If you get this right, you achieve:

* **predictable behavior under failure**
* **long-lived sessions**
* **confidence for real workflows**

If you cut corners here, users will encounter:

* stuck kernels
* ghost outputs
* unrecoverable buffers

---
