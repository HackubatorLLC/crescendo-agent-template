# Project Intake

Drop your project requirements here before starting a Crescendo run:

- **PRDs** — Product Requirements Documents
- **Architecture diagrams** — System design, data flow
- **UI mockups** — Wireframes, Figma exports
- **Constraints** — Regulations, compliance requirements, style guides
- **Source code** — Existing code to extend or refactor

## Before You Start

Run `just sanitize-inputs` to strip prompt injections and invisible characters.
Only files in `input/.sanitized/` will be consumed by agents.

> **Note:** Binary files (PDF, DOCX, XLSX) cannot be auto-sanitized and require manual review.
