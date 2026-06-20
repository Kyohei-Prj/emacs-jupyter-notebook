# EJN Testing Strategy

## Version 1.0

---

# 1. Purpose

This document defines the testing strategy for the Emacs Jupyter Notebook (EJN) project.

Its objectives are to:

* Guarantee architectural correctness.
* Prevent regressions.
* Validate interoperability.
* Ensure performance targets.
* Enable fearless refactoring.
* Support long-term maintainability.

Testing is treated as part of the product architecture rather than a post-development activity.

---

# 2. Testing Philosophy

## T1. Test the Contracts

Tests should verify documented interfaces and observable behavior rather than implementation details.

Changing an internal implementation should not require changing tests if the public contract remains unchanged.

---

## T2. Prefer Deterministic Tests

Avoid:

* Timing-dependent tests.
* Network-dependent tests.
* Random execution order.
* External state.

Every test should be reproducible.

---

## T3. Layered Testing

Each architectural layer is tested independently before integration.

```text
Property Tests
      │
      ▼
Unit Tests
      │
      ▼
Module Tests
      │
      ▼
Contract Tests
      │
      ▼
Integration Tests
      │
      ▼
End-to-End Tests
      │
      ▼
Performance Tests
```

---

## T4. Fast Feedback

The majority of tests should execute within seconds.

Long-running benchmarks are isolated from routine CI.

---

## T5. Test Invariants, Not Incidental Behavior

Architectural invariants receive explicit tests.

Examples:

* Stable identities.
* Transaction atomicity.
* Event ordering.
* Synchronization correctness.
* Scheduler guarantees.

---

# 3. Test Pyramid

| Layer             | Purpose               | Approx. Share |
| ----------------- | --------------------- | ------------- |
| Property Tests    | Invariants            | 10%           |
| Unit Tests        | Individual functions  | 45%           |
| Module Tests      | Subsystem behavior    | 20%           |
| Contract Tests    | Public APIs           | 10%           |
| Integration Tests | Cross-module behavior | 10%           |
| End-to-End Tests  | User workflows        | 5%            |

---

# 4. Test Categories

## 4.1 Property-Based Tests

Purpose:

Verify mathematical and structural invariants across many generated inputs.

Examples:

* Cell ID uniqueness.
* Serializer round-trips.
* Split/merge consistency.
* Position map correctness.
* Incremental parser equivalence.
* Transaction rollback.
* Event ordering.

Recommended libraries:

* `ert`
* Property-testing library (or custom generators if no mature library meets requirements)

---

## 4.2 Unit Tests

Every exported function should have unit tests.

Examples:

* Cell insertion.
* Cell deletion.
* UUID generation.
* MIME dispatch.
* Overlay planning.
* Dirty-region calculation.
* Metadata parsing.

---

## 4.3 Module Tests

Each subsystem is tested in isolation using mocks or stubs where appropriate.

Modules:

* Model
* Transactions
* Events
* Synchronization
* Scheduler
* Backend
* Rendering
* Language services
* Serialization
* Plugins

---

## 4.4 Contract Tests

Every public interface has a reusable compliance suite.

Examples:

### Backend Contract

A backend implementation must satisfy:

* Start kernel.
* Stop kernel.
* Execute code.
* Interrupt execution.
* Restart session.
* Publish events.
* Advertise capabilities.

The same contract suite is executed against every backend implementation.

---

### Serializer Contract

Every serializer must satisfy:

* Read.
* Write.
* Preserve metadata.
* Round-trip.
* Version compatibility.

---

### Language Provider Contract

Every provider must support advertised capabilities consistently.

---

### MIME Renderer Contract

Every renderer must:

* Accept supported MIME types.
* Produce deterministic output.
* Handle malformed input safely.
* Provide fallback behavior.

---

# 5. Integration Tests

Integration tests verify interaction between subsystems.

Examples:

Synchronization → Model

Model → Transactions

Scheduler → Backend

Backend → Events

Events → Renderer

Language Provider → Virtual Document

Persistence → Notebook Model

Plugins → Service Registry

---

# 6. End-to-End Tests

Simulate realistic user workflows.

Examples:

## Create Notebook

Create notebook

↓

Insert cells

↓

Save

↓

Reload

↓

Verify structure

---

## Execute Notebook

Start kernel

↓

Execute cells

↓

Receive outputs

↓

Restart kernel

↓

Re-execute

↓

Verify outputs

---

## LSP Workflow

Edit code

↓

Synchronize virtual document

↓

Receive diagnostics

↓

Display diagnostics

↓

Rename symbol

↓

Verify edits

---

## Multi-Window Workflow

Open notebook

↓

Split window

↓

Fold independently

↓

Execute cell

↓

Verify shared model and independent view state

---

# 7. Performance Testing

Performance tests are automated and repeatable.

## Parsing Benchmarks

Measure:

* Full parse
* Incremental parse
* Dirty-region updates

Notebook sizes:

* 10 cells
* 100 cells
* 1,000 cells
* 10,000 cells

---

## Rendering Benchmarks

Measure:

* Initial render
* Viewport update
* Fold/unfold
* Output virtualization

---

## Scheduler Benchmarks

Measure:

* Queue latency
* Execution throughput
* Cancellation latency

---

## Serialization Benchmarks

Measure:

* Load time
* Save time
* Round-trip fidelity

---

## Memory Benchmarks

Track:

* Overlay count
* Live objects
* Render cache
* Peak memory

---

# 8. Stress Testing

Stress scenarios include:

* 100,000-line notebooks.
* Thousands of cells.
* Large image outputs.
* Continuous streaming output.
* Frequent edits.
* Rapid execution.
* Multiple kernels.
* Multiple windows.

Success is defined by stability and graceful degradation.

---

# 9. Fuzz Testing

Fuzz targets:

* `.ipynb` parser.
* `.ejn` parser.
* MIME renderer inputs.
* Metadata parser.
* Synchronization engine.

Malformed inputs must never crash Emacs or corrupt notebook state.

---

# 10. Regression Testing

Every reported bug receives:

1. A failing regression test.
2. A fix.
3. A passing regression test.

No bug is considered resolved without a permanent test.

---

# 11. Compatibility Testing

Supported platforms:

* GNU/Linux
* macOS
* Windows

Supported environments:

* GUI Emacs
* `emacs -nw`

Supported Emacs versions:

* Project minimum supported release.
* Latest stable release.
* Development snapshot (non-blocking).

---

# 12. Interoperability Testing

Notebook corpus includes:

* Python
* Julia
* R
* Bash
* Common Lisp
* Mixed-language notebooks

Round-trip testing verifies:

* Cell order.
* Metadata.
* Outputs.
* Attachments.
* Execution counts.

---

# 13. Continuous Integration

Every pull request executes:

* Byte compilation.
* Linting.
* Unit tests.
* Module tests.
* Contract tests.
* Integration tests.
* Documentation validation.

Nightly CI additionally executes:

* Full benchmark suite.
* Stress tests.
* Fuzz tests.
* Large notebook corpus.

---

# 14. Code Coverage

Coverage targets:

| Component         | Minimum |
| ----------------- | ------- |
| Core Model        | 100%    |
| Transactions      | 100%    |
| Event Bus         | 100%    |
| Synchronization   | 95%     |
| Scheduler         | 95%     |
| Backend Interface | 100%    |
| Jupyter Backend   | 90%     |
| Rendering         | 90%     |
| Language Services | 90%     |
| Serialization     | 100%    |
| Plugin Framework  | 95%     |
| UI Commands       | 85%     |

Coverage is a quality indicator, not the primary success metric.

---

# 15. Architectural Invariant Tests

Dedicated tests verify:

* Stable object identities.
* Transaction atomicity.
* Event publication after commit.
* Immutable identity fields.
* Derived state consistency.
* View state isolation.
* Scheduler ordering guarantees.
* Capability negotiation.
* Serializer round-trip fidelity.

These tests protect the core architectural assumptions of EJN.

---

# 16. Golden Test Corpus

The project maintains a version-controlled corpus of notebooks covering:

* Small notebooks.
* Large notebooks.
* Rich MIME outputs.
* Markdown-heavy documents.
* Multiple kernels.
* Error cases.
* Malformed files.

This corpus serves as the basis for regression, interoperability, and serialization testing.

---

# 17. Acceptance Criteria

A release is eligible when:

* All architectural invariant tests pass.
* All contract suites pass.
* Golden corpus round-trips without unexpected changes.
* Performance benchmarks meet documented budgets.
* No known critical regressions remain.
* GUI and terminal workflows satisfy feature-parity requirements where applicable.
* CI passes on all supported platforms and Emacs versions.
