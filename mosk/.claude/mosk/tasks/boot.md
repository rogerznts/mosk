# boot

Analyze the consuming project and generate context files in `.claude/commands/` to equip the AI with knowledge of the project's stack, patterns, architecture, and workflows.

This is a one-shot task — no persona, no interactive menu. Execute all phases in sequence and report results.

## Outline

### Phase 1 — Read and Analyze

Map the project structure and extract architectural signals from the source code.

1. **Read directory structure** (max 3 levels deep):
   - Run: `find . -maxdepth 3 -not -path './.git/*' -not -path './node_modules/*' -not -path './vendor/*' -not -path './.claude/*' | sort`
   - Identify the primary language, framework, and project layout.

2. **Read reference files** (read all that exist):
   - `README.md` or `readme.md`
   - `package.json` / `composer.json` / `pyproject.toml` / `Gemfile` / `go.mod` / `Cargo.toml` / `build.gradle`
   - `.env.example` or `.env.sample`
   - Primary config files: `tsconfig.json`, `vite.config.*`, `webpack.config.*`, `next.config.*`, `nuxt.config.*`, `laravel.json`, `settings.py`, `application.yml`, `docker-compose.yml`, `Makefile`

3. **Sample source files** — read at least 3 files from each layer that exists:
   - **Controllers / Routes**: entry points, request handling, response shaping
   - **Services / Use Cases**: business logic, orchestration
   - **Models / Repositories / Entities**: data structures, DB access patterns
   - **UI Components** (if frontend exists): component patterns, state management, API calls
   - **Tests**: test style, tooling, coverage conventions

4. **Extract signals** from what you read. For each area below, note the concrete pattern found or write "nao identificado" if no evidence exists:
   - Tech stack (languages, frameworks, runtimes, versions)
   - Architectural pattern (MVC, Clean Architecture, Hexagonal, Feature Slicing, etc.)
   - Folder conventions and naming rules
   - Error handling strategy (exceptions, Result types, HTTP codes)
   - Authentication / authorization mechanism
   - Database access layer (ORM, raw SQL, migrations)
   - API response envelope (shape, status codes, pagination)
   - Test tooling and test file location convention
   - Logging and observability approach
   - Configuration and secrets management

---

### Phase 2 — Generate Files in `.claude/commands/`

Create the output directory if it does not exist: `mkdir -p .claude/commands`

Write the following files. Use real code examples from the project. If a pattern was not identified, state "nao identificado" — never invent patterns. Keep each file under 400 lines. Write for the AI, not for humans: be prescriptive and direct.

---

#### `.claude/commands/system-design.md`

```
# System Design

## Overview
[One paragraph describing what this system does and who uses it]

## Architecture Pattern
[Pattern name + brief rationale, e.g., "Clean Architecture — domain layer isolated from infra"]

## Layer Diagram
[ASCII or text diagram showing layers and their relationships]

## Module Map
[List of top-level modules/packages and what each owns]

## Request Flow
[Step-by-step: request enters → traverses which layers → exits]

## External Dependencies
[Third-party services, APIs, databases, queues — one line each]

## Architectural Decision Rules
[Non-negotiable rules the AI must follow when making structural changes]
[e.g., "Domain layer must not import from infrastructure", "All queries go through Repository interfaces"]
```

---

#### `.claude/commands/backend.md`

```
# Backend

## Stack
[Language + version, framework + version, runtime]

## Folder Structure
[Annotated tree of backend source, 2-3 levels deep]

## Endpoint Pattern
[Naming convention, HTTP method mapping, versioning, route registration]

## Services / Use Cases
[How business logic is organized, naming conventions, return types]

## Models / Repositories
[ORM or query builder in use, naming, migration pattern, relation conventions]

## Error Handling
[How errors propagate from service to controller to response]

## API Response Shape
[Actual envelope structure with field names and types — use a real example]

## Authentication
[Mechanism, token format, middleware/guard pattern, protected vs public routes]

## Migrations
[How to create, run, and rollback migrations]

## Tests
[Test framework, file naming, how to run, what to test at each layer]

## Rules for the AI
- [Prescriptive rule 1]
- [Prescriptive rule 2]
- ...
```

---

#### `.claude/commands/frontend.md`

**Omit this file entirely if no frontend code exists in the project.**

```
# Frontend

## Stack
[Framework + version, build tool, CSS approach, state management]

## Component Structure
[Naming convention, file organization, co-location rules]

## Styling
[CSS system in use, class naming, theming conventions]

## State Management
[Library or pattern, when to use local vs global state]

## API Calls
[HTTP client used, where calls live, error handling on the client]

## Forms
[Validation library, form state approach, submission pattern]

## Tests
[Component test framework, what to test, how to run]

## Rules for the AI
- [Prescriptive rule 1]
- [Prescriptive rule 2]
- ...
```

---

#### `.claude/commands/code-patterns.md`

```
# Code Patterns

## Naming Conventions
| Artifact | Convention | Example |
|---|---|---|
| Files | ... | ... |
| Classes | ... | ... |
| Functions/Methods | ... | ... |
| Variables | ... | ... |
| Constants | ... | ... |
| Database tables | ... | ... |

## Comments
[When and how to comment — what the codebase shows]

## Imports / Module Resolution
[Import order, aliases, barrel files if used]

## Types / Interfaces
[Typing approach: strict, gradual, inferred? Where interfaces live]

## Logging
[Logger used, log levels, what gets logged]

## Configuration Access
[How config/env vars are accessed — direct, centralized config object, etc.]

## Security Conventions
[Input validation, sanitization, known patterns in use]

## Anti-patterns (do NOT do these)
- [Anti-pattern 1 observed or explicitly forbidden]
- [Anti-pattern 2]
```

---

#### `.claude/commands/workflows.md`

```
# Workflows

## Running Locally
[Step-by-step: install deps → configure env → start server → verify]

## Adding a New Feature
[Step-by-step based on observed project conventions: where to add files, what to register]

## Running Tests
[Commands for unit, integration, e2e — one line each]

## Commits and Branches
[Branch naming convention, commit message format if one is found]

## Deploy
[If deployment config exists: how to build, where artifacts go, deploy command]

## Useful Commands
[The 5-10 commands used most often in this project with brief descriptions]

## PR Checklist
- [ ] Tests pass
- [ ] Linting passes
- [Add items based on what the project enforces]
```

---

### Phase 3 — Validate and Report

After writing all files, output a summary:

1. **Files created** — list each file with a one-line description of what it captures.

2. **Uncertainties** — list any patterns marked "nao identificado" or areas where evidence was thin. Suggest which source files would resolve each uncertainty.

3. **Suggested additional files** — based on what you found, suggest specific command files that could add value for this project. Examples:
   - `.claude/commands/auth.md` if auth logic is complex
   - `.claude/commands/integrations.md` if there are many third-party integrations
   - `.claude/commands/data-model.md` if the domain model is large
   - `.claude/commands/infra.md` if there is non-trivial infrastructure config

4. **Ask the user**: "Algum modulo ou dominio merece um arquivo de comando proprio? Se sim, me diga qual e eu gero agora."

## Constraints

- Never invent patterns. If not observed in code, write "nao identificado".
- Use real code snippets from the project as examples — not made-up samples.
- Maximum 400 lines per generated file.
- Files are written for the AI, not for humans — prescriptive and direct, no preamble.
- Works on both new projects (greenfield) and existing codebases (brownfield).
- If a layer does not exist (e.g., no frontend, no tests), omit its section from the relevant file rather than writing "nao identificado" throughout.
