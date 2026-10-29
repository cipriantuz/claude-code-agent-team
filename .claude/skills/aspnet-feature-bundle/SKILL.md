---
name: aspnet-feature-bundle
disable-model-invocation: true
description: Trigger when user says "implement feature", "add complete feature", "from zero to merge", "end-to-end feature" — orchestrate architect → backend → qa sequentially for a full feature delivery. NOT for a single quick endpoint or controller scaffold — use `aspnet-controller` for that.
---

# ASP.NET Core Feature Bundle Orchestrator

**Sequential only. Never parallelize steps. Each step gates the next.**

## Step 1 — Gather inputs

Ask the owner before anything else:
- **Feature name** (short slug, e.g., `order-status-tracking`)
- **Description** (2-3 sentences: what it does, who uses it, why now)
- **Target project path** (absolute)

## Step 2 — Architecture design

Launch `@software-architect`:

```
Design feature `{feature-name}`: {description}

Target project: {project-path}

Produce ONE file at `docs/architecture/{feature-name}.md` containing:
- Tech stack confirmation (why current stack fits, or propose alternative)
- Components to create (files, layers)
- API contracts (routes, request/response shapes)
- DB schema changes if any
- Open questions for the owner

DO NOT write implementation code.
```

## Step 3 — Alignment check (HARD GATE)

After architect completes, read `docs/architecture/{feature-name}.md` and summarize to the owner:
1. What will be built (components list)
2. API surface (routes)
3. Any risks or open questions from architect

**WAIT for explicit confirmation from the owner ("ok", "go") before Step 4.**
If the owner changes scope, re-run Step 2 with updated description.

## Step 4 — Backend implementation

Launch `@backend-developer`:

```
Implement feature `{feature-name}` following `docs/architecture/{feature-name}.md`.

Rules:
- Create branch `feature/{feature-name}` before writing any code
- Follow the file structure in the architecture doc
- Run `dotnet build` at the end — zero warnings policy
- Report which files were created/modified
```

## Step 5 — QA

Launch `@qa-engineer`:

```
Write xUnit tests for feature `{feature-name}` implemented by backend-developer.

Architecture doc: `docs/architecture/{feature-name}.md`

Requirements:
- Unit tests for service layer (mock dependencies)
- Integration test per endpoint using WebApplicationFactory
- Run `dotnet test`, report pass/fail count
- Flag any code smell or missing validation
```

## Step 6 — Wrap-up

Report to the owner:
- Files created (grouped by layer)
- Test results (X passed, Y failed)
- Suggested commit message (conventional commits format):
  ```
  feat({feature-name}): {one-line description}
  ```
- Next step: the owner reviews, then `git commit` + PR

## Rules

- Steps 2 → 3 → 4 → 5 are strictly sequential — never overlap
- If any step fails (build error, test failure), fix before advancing
- Architecture doc is the source of truth — backend must not deviate silently
