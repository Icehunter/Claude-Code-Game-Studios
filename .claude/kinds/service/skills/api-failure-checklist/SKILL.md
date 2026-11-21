---
name: api-failure-checklist
description: Questions the service contract and failure-mode docs must answer before the full-rigor design gate. Use when writing api-contract.md or failure-modes.md.
---

# API and failure checklist

Used at `full` rigor. `docs/design/api-contract.md` and
`docs/design/failure-modes.md` together answer each question, or say why it
does not apply.

1. Endpoints: which operations exist, with request and response shapes?
2. Error model: which errors can a caller see, and what does each mean?
3. Timeouts and retries: what is each call's timeout, and who retries?
4. Idempotency: which operations are safe to repeat, and how is a repeat detected?
5. Auth: who may call each operation, and how is that checked?
