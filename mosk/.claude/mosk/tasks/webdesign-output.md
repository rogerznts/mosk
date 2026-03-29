# Task: Full Output Enforcement

Override default LLM truncation behavior. Enforce complete code generation with no placeholders.

## When to use

- User asks for full, complete, unabridged output
- Any task requiring exhaustive code generation
- When previous output was truncated or contained placeholders

## Baseline

Treat every task as production-critical. A partial output is a broken output. Do not optimize for brevity — optimize for completeness. If the user asks for a full file, deliver the full file. If the user asks for 5 components, deliver 5 components. No exceptions.

## Banned Output Patterns

The following are hard failures. Never produce them:

**In code blocks:**
`// ...`, `// rest of code`, `// implement here`, `// TODO`, `/* ... */`, `// similar to above`, `// continue pattern`, `// add more as needed`, bare `...` standing in for omitted code

**In prose:**
"Let me know if you want me to continue", "I can provide more details if needed", "for brevity", "the rest follows the same pattern", "similarly for the remaining", "and so on" (when replacing actual content), "I'll leave that as an exercise"

**Structural shortcuts:**
Outputting a skeleton when the request was for a full implementation. Showing first and last sections while skipping the middle. Replacing repeated logic with one example and a description. Describing what code should do instead of writing it.

## Execution Process

1. **Scope** — Read the full request. Count how many distinct deliverables are expected. Lock that number.
2. **Build** — Generate every deliverable completely. No partial drafts.
3. **Cross-check** — Before output, re-read the original request. Compare deliverable count against scope count. If anything is missing, add it.

## Handling Long Outputs

When a response approaches the token limit:

- Do not compress remaining sections.
- Do not skip ahead to a conclusion.
- Write at full quality up to a clean breakpoint (end of a function, file, or section).
- End with:

```
[PAUSED — X of Y complete. Send "continue" to resume from: next section name]
```

On "continue", pick up exactly where you stopped. No recap, no repetition.

## Quick Check

Before finalizing any response:
- No banned patterns from the list above appear anywhere
- Every item the user requested is present and finished
- Code blocks contain actual runnable code, not descriptions
- Nothing was shortened to save space
