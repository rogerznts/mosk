# spec-specify

Create or update the feature specification from a natural language feature description.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

The text the user typed after the triggering command **is** the feature description. Assume you always have it available in this conversation even if `$ARGUMENTS` appears literally below. Do not ask the user to repeat it unless they provided an empty command.

Given that feature description, do this:

1. **Determine the spec type** (`feature`, `fix`, `hotfix`, `gmud`, `refactor`, or `experimental`):
   - Analyze the feature description for signals:
     - `feature` → new functionality, new capability, new product area
     - `fix` → bug correction, non-urgent defect
     - `hotfix` → urgent production fix, critical blocker, security vulnerability
     - `gmud` → change management, rollout, deployment procedure, GMUD
     - `refactor` → code restructuring, performance improvement, tech-debt without new features
     - `experimental` → exploration, proof-of-concept, spike, undated research
   - If type is already explicit in the user description, use it directly.
   - If ambiguous, make an informed guess and state it (do not ask unless genuinely unclear between `fix` and `hotfix`, or `feature` and `refactor`).
   - Store the chosen type as SPEC_TYPE for use in the script call.

2. **Generate a concise short name** (2-4 words) for the branch:
   - Analyze the feature description and extract the most meaningful keywords
   - Create a 2-4 word short name that captures the essence of the feature
   - **Do NOT include the type word in the short name** — it is handled by `--type`
   - Use action-noun or noun format when possible (e.g., "user-auth", "payment-timeout")
   - Preserve technical terms and acronyms (OAuth2, API, JWT, etc.)
   - Keep it concise but descriptive enough to understand the feature at a glance
   - Examples:
     - "I want to add user authentication" → type: `feature`, name: `user-auth`
     - "Implement OAuth2 integration for the API" → type: `feature`, name: `oauth2-api-integration`
     - "Create a dashboard for analytics" → type: `feature`, name: `analytics-dashboard`
     - "Fix payment processing timeout bug" → type: `fix`, name: `payment-timeout`
     - "Urgent: fix SQL injection in login" → type: `hotfix`, name: `login-sql-injection`
     - "Deploy rollback procedure for v2.1" → type: `gmud`, name: `rollback-v2-1`

3. **Check for existing branches before creating new one**:

   a. **Check current branch first**:
      Run: `git branch --show-current`

      - **If the current branch is NOT `main` or `master`**:
        - Inform the user: "You are already on branch `{current-branch}`. Using this branch for the feature."
        - Skip steps 3c–3e (do not run the script `create-new-feature.sh`).
        - Use `{current-branch}` as BRANCH_NAME.
        - Infer the SPEC_FILE path from the branch name convention:
          if the branch matches `{number}-{type}-{short-name}`, use `docs/specs/{number}-{type}-{short-name}/spec.md`;
          otherwise create `docs/specs/{current-branch}/spec.md`.
        - Proceed to step 4.
      - **If on `main` or `master`**: continue with steps 3c–3e below.

   b. First, fetch all remote branches to ensure we have the latest information:
      ```bash
      git fetch --all --prune
      ```

   c. Find the highest feature number across all sources for the short-name:
      - Remote branches: `git ls-remote --heads origin | grep -E 'refs/heads/[0-9]+-[a-z]+-<short-name>$'`
      - Local branches: `git branch | grep -E '^[* ]*[0-9]+-[a-z]+-<short-name>$'`
      - Specs directories: Check for directories matching `specs/[0-9]+-*-<short-name>`

   d. Determine the next available number:
      - Extract all numbers from all three sources
      - Find the highest number N
      - Use N+1 for the new branch number

   e. Run the script `.claude/mosk/scripts/create-new-feature.sh` with the calculated number, type, and short-name:
      - Pass `--json` (for JSON output), `--type SPEC_TYPE`, `--number N+1`, `--short-name "your-short-name"` and the feature description as the last positional argument
      - Bash example: `.claude/mosk/scripts/create-new-feature.sh --json --type feature --number 5 --short-name "user-auth" "Add user authentication"`
      - Bash example (fix): `.claude/mosk/scripts/create-new-feature.sh --json --type fix --number 8 --short-name "payment-timeout" "Fix payment processing timeout"`

   **IMPORTANT**:
   - Check all three sources (remote branches, local branches, specs directories) to find the highest number
   - Only match branches/directories with the exact short-name pattern
   - If no existing branches/directories found with this short-name, start with number 1
   - You must only ever run this script once per feature
   - The JSON is provided in the terminal as output - always refer to it to get the actual content you're looking for
   - The JSON output will contain BRANCH_NAME and SPEC_FILE paths (format: `{###}-{tipo}-{nome}`)
   - For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot")

4. Load `.claude/mosk/templates/spec-template.md` to understand required sections.

5. Follow this execution flow:

    1. Parse user description from Input
       If empty: ERROR "No feature description provided"
    2. Extract key concepts from description
       Identify: actors, actions, data, constraints
    3. For unclear aspects:
       - Make informed guesses based on context and industry standards
       - Only mark with [NEEDS CLARIFICATION: specific question] if:
         - The choice significantly impacts feature scope or user experience
         - Multiple reasonable interpretations exist with different implications
         - No reasonable default exists
       - **LIMIT: Maximum 3 [NEEDS CLARIFICATION] markers total**
       - Prioritize clarifications by impact: scope > security/privacy > user experience > technical details
    4. Fill User Scenarios & Testing section
       If no clear user flow: ERROR "Cannot determine user scenarios"
    5. Generate Functional Requirements
       Each requirement must be testable
       Use reasonable defaults for unspecified details (document assumptions in Assumptions section)
    6. Define Success Criteria
       Create measurable, technology-agnostic outcomes
       Include both quantitative metrics (time, performance, volume) and qualitative measures (user satisfaction, task completion)
       Each criterion must be verifiable without implementation details
    7. Identify Key Entities (if data involved)
    8. Return: SUCCESS (spec ready for planning)

6. Write the specification to SPEC_FILE using the template structure, replacing placeholders with concrete details derived from the feature description (arguments) while preserving section order and headings.

7. **Specification Quality Validation**: After writing the initial spec, validate it against quality criteria:

   a. **Create Spec Quality Checklist**: Generate a checklist file at `FEATURE_DIR/checklists/requirements.md` using the checklist template structure with these validation items:

      ```markdown
      # Specification Quality Checklist: [FEATURE NAME]

      **Purpose**: Validate specification completeness and quality before proceeding to planning
      **Created**: [DATE]
      **Feature**: [Link to spec.md]

      ## Content Quality

      - [ ] No implementation details (languages, frameworks, APIs)
      - [ ] Focused on user value and business needs
      - [ ] Written for non-technical stakeholders
      - [ ] All mandatory sections completed

      ## Requirement Completeness

      - [ ] No [NEEDS CLARIFICATION] markers remain
      - [ ] Requirements are testable and unambiguous
      - [ ] Success criteria are measurable
      - [ ] Success criteria are technology-agnostic (no implementation details)
      - [ ] All acceptance scenarios are defined
      - [ ] Edge cases are identified
      - [ ] Scope is clearly bounded
      - [ ] Dependencies and assumptions identified

      ## Feature Readiness

      - [ ] All functional requirements have clear acceptance criteria
      - [ ] User scenarios cover primary flows
      - [ ] Feature meets measurable outcomes defined in Success Criteria
      - [ ] No implementation details leak into specification

      ## Notes

      - Items marked incomplete require spec updates before `*spec-clarify` or `*spec-plan`
      ```

   b. **Run Validation Check**: Review the spec against each checklist item:
      - For each item, determine if it passes or fails
      - Document specific issues found (quote relevant spec sections)

   c. **Handle Validation Results**:

      - **If all items pass**: Mark checklist complete and proceed to step 6

      - **If items fail (excluding [NEEDS CLARIFICATION])**:
        1. List the failing items and specific issues
        2. Update the spec to address each issue
        3. Re-run validation until all items pass (max 3 iterations)
        4. If still failing after 3 iterations, document remaining issues in checklist notes and warn user

      - **If [NEEDS CLARIFICATION] markers remain**:
        1. Extract all [NEEDS CLARIFICATION: ...] markers from the spec
        2. **LIMIT CHECK**: If more than 3 markers exist, keep only the 3 most critical (by scope/security/UX impact) and make informed guesses for the rest
        3. For each clarification needed (max 3), present options to user in this format:

           ```markdown
           ## Question [N]: [Topic]

           **Context**: [Quote relevant spec section]

           **What we need to know**: [Specific question from NEEDS CLARIFICATION marker]

           **Suggested Answers**:

           | Option | Answer | Implications |
           |--------|--------|--------------|
           | A      | [First suggested answer] | [What this means for the feature] |
           | B      | [Second suggested answer] | [What this means for the feature] |
           | C      | [Third suggested answer] | [What this means for the feature] |
           | Custom | Provide your own answer | [Explain how to provide custom input] |

           **Your choice**: _[Wait for user response]_
           ```

        4. **CRITICAL - Table Formatting**: Ensure markdown tables are properly formatted
        5. Number questions sequentially (Q1, Q2, Q3 - max 3 total)
        6. Present all questions together before waiting for responses
        7. Wait for user to respond with their choices for all questions
        8. Update the spec by replacing each [NEEDS CLARIFICATION] marker with the user's selected or provided answer
        9. Re-run validation after all clarifications are resolved

   d. **Update Checklist**: After each validation iteration, update the checklist file with current pass/fail status

8. Report completion with branch name (format: `{###}-{tipo}-{nome}`), spec file path, checklist results, and readiness for the next phase (`*spec-clarify` or `*spec-plan`).

**NOTE:** The script creates and checks out the new branch and initializes the spec file before writing.

## General Guidelines

- Focus on **WHAT** users need and **WHY**.
- Avoid HOW to implement (no tech stack, APIs, code structure).
- Written for business stakeholders, not developers.
- DO NOT create any checklists that are embedded in the spec. That will be a separate command.

### Section Requirements

- **Mandatory sections**: Must be completed for every feature
- **Optional sections**: Include only when relevant to the feature
- When a section doesn't apply, remove it entirely (don't leave as "N/A")

### For AI Generation

When creating this spec from a user prompt:

1. **Make informed guesses**: Use context, industry standards, and common patterns to fill gaps
2. **Document assumptions**: Record reasonable defaults in the Assumptions section
3. **Limit clarifications**: Maximum 3 [NEEDS CLARIFICATION] markers
4. **Prioritize clarifications**: scope > security/privacy > user experience > technical details
5. **Think like a tester**: Every vague requirement should fail the "testable and unambiguous" checklist item

### Success Criteria Guidelines

Success criteria must be:

1. **Measurable**: Include specific metrics (time, percentage, count, rate)
2. **Technology-agnostic**: No mention of frameworks, languages, databases, or tools
3. **User-focused**: Describe outcomes from user/business perspective
4. **Verifiable**: Can be tested/validated without knowing implementation details
