# Design record

## Approach
A CLI writes the report as CSV from the in-memory model.

## Constraint check
- C1: no database; the report is built in memory.

## Decision log
- 2026-11-21: in-memory model because C1. Rejected: SQLite.
