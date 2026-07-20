# security-review

Review the pending changes on the current branch for real, exploitable security vulnerabilities. Diff-aware and context-driven — this goes beyond pattern matching: understand intent, trace data flow, and judge actual exploitability.

## Goal

Produce a short, high-signal security report that answers one question clearly: is it safe to ship these changes? Findings must be actionable, and false positives must be aggressively filtered out.

## Scope

Analyze only the files changed on the current branch (`git diff` against the base branch — `main`/`master`/`develop`, or the branch's merge-base). Use the rest of the repository as **context**, not as review scope. If a spec is active, resolve its id from `spec-meta.yaml`.

## Workflow

### Phase 1 — Repository Context Research

Use file-search tools before judging anything:

- Identify the security frameworks and libraries already in use (validation, auth, crypto, ORM).
- Find the established secure-coding patterns in the codebase.
- Examine existing sanitization and validation patterns.
- Understand the project's security and threat model (read `.claude/rules/*.md`).

### Phase 2 — Comparative Analysis

- Compare the changed code against the existing secure patterns.
- Identify deviations from established secure practices.
- Flag inconsistent security implementations.
- Flag code that introduces new attack surface.

### Phase 3 — Vulnerability Assessment

For each modified file:

- Trace data flow from user-controlled inputs to sensitive operations (sinks).
- Look for privilege boundaries being crossed unsafely.
- Identify injection points and unsafe deserialization.

**Categories to consider:** injection (SQL, command, LDAP, XPath, NoSQL, XXE, template); authn/authz (broken auth, privilege escalation, IDOR, session flaws); data exposure (hardcoded secrets, sensitive logging, PII, information disclosure); weak crypto (bad algorithms, key management, insecure RNG); missing input validation; business logic (race conditions, TOCTOU); insecure config (permissive CORS, missing headers, unsafe defaults); supply chain (typosquatting); code execution (RCE via deserialization, pickle/eval injection); XSS (reflected, stored, DOM-based).

### Phase 4 — Severity and confidence

Assign each finding a **severity**:

- **HIGH** — directly exploitable, leading to RCE, data breach, or authentication bypass.
- **MEDIUM** — requires specific conditions but has significant impact.
- **LOW** — defense-in-depth or lower-impact issues.

Assign each finding a **confidence** (0–1):

- 0.9–1.0 — certain exploit path identified.
- 0.8–0.9 — clear vulnerability pattern with known exploitation methods.
- 0.7–0.8 — suspicious pattern needing specific conditions.
- Below 0.7 — **do not report** (too speculative).

**Report only findings with confidence > 0.8.**

### Phase 5 — False-positive filtering (do not report these)

Exclude a finding when it is any of:

1. Denial of Service (DoS) or resource-exhaustion attacks.
2. Secrets/credentials stored on disk if they are otherwise secured.
3. Rate-limiting concerns or service-overload scenarios.
4. Memory consumption or CPU exhaustion.
5. Missing input validation on non-security-critical fields without proven security impact.
6. Input-sanitization concerns for CI/workflow files unless clearly triggerable by untrusted input.
7. A lack of hardening measures — code is not expected to implement every best practice.
8. Race conditions or timing attacks that are theoretical rather than practical.
9. Vulnerabilities from outdated third-party libraries.
10. Memory-safety issues (buffer overflow, use-after-free).
11. Files that are only unit tests or used only for testing.
12. Log spoofing (unsanitized user input written to logs).
13. SSRF that only controls the path.
14. Including user-controlled content in AI system prompts.
15. Regex injection.
16. Regex DoS.
17. Insecure documentation.

**File-type awareness:** only flag memory-safety issues in C/C++ files; only flag SSRF in files that make outbound requests, not HTML.

### Phase 6 — Write the report

1. Read `.claude/mosk/core-config.yaml` and resolve `qa.qaLocation`. Write the report under `{qa.qaLocation}/security/`.
2. Filename: `security-review-{spec-id}.md` when a spec is active, else `security-review-{branch}.md`.
3. Report contents:
   - A findings table: `file:line`, severity, category, confidence, exploit_scenario, recommendation.
   - A summary: files reviewed, counts per severity, review completed (yes/no).
   - A final **security verdict** line the QA gate consumes:
     `SECURITY: PASS` (no HIGH/MEDIUM), `SECURITY: CONCERNS` (MEDIUM present, or a HIGH with a clear fix), or `SECURITY: FAIL` (unresolved HIGH).
4. When a spec is active, also drop a reference to the report path inside `specs/{id}/` (e.g., in the spec's QA notes) so the gate can find it.

## Rules

- Start with the findings and the final verdict.
- One or two sentences per finding — `file:line`, the exploit path, the fix.
- Use HIGH/MEDIUM/LOW severity only.
- This is not a pipeline phase: do **not** change `current_phase` in `spec-meta.yaml`.
- Not hardened against prompt injection — run only on trusted code; warn the user for untrusted diffs.
