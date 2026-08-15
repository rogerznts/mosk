<!-- Inspired by BMAD and SpecKit -->

# Enrich Story Task

## Purpose

To identify the next logical story based on project progress and epic definitions, and then to enrich it with all necessary technical context, requirements, and acceptance criteria — producing a comprehensive, self-contained, and actionable story file using the `Story Template`, ready for efficient implementation by a Developer Agent with minimal need for additional research.

> **Note on naming:** this task was previously called `draft-story`. The name was changed to `enrich-story` to disambiguate from `create-story` (PO). `create-story` emits the formal story from the PRD/epic; `enrich-story` takes that story and injects architectural/technical context for dev-readiness.

## SEQUENTIAL Task Execution (Do not proceed until current Task is complete)

### 0. Load Core Configuration and Check Workflow

- Load `.claude/mosk/core-config.yaml` from the project root
- If the file does not exist, HALT and inform the user: "core-config.yaml not found. This file is required for story creation. Please ensure MOSK is properly installed in this project (run `npx degit rogerznts/mosk/mosk .` from the project root) and that core-config.yaml exists at `.claude/mosk/core-config.yaml`."
- Extract key configurations: `specs.root`, `specs.storiesSubdir`, `prd.*`, `architecture.*`
- Determine the current spec: read `docs/specs/*/spec-meta.yaml` and pick the one with `status: active` matching the current branch (or ask the user if multiple match). The stories root for this draft is `{specs.root}/{current_spec_id}/{specs.storiesSubdir}`.

### 1. Identify Next Story for Preparation

#### 1.1 Locate Epic Files and Review Existing Stories

- Locate epic files in `{prd.root}/` (sharded by default; look for `epic-*.md` patterns or dedicated sections) or in `{specs.root}/{current_spec_id}/` if the epic is spec-local.
- If the stories folder `{specs.root}/{current_spec_id}/{specs.storiesSubdir}/` has story files, load the highest `{epicNum}.{storyNum}.story.md` file
- **If highest story exists:**
  - Verify status is 'Done'. If not, alert user: "ALERT: Found incomplete story! File: {lastEpicNum}.{lastStoryNum}.story.md Status: [current status] You should fix this story first, but would you like to accept risk & override to create the next story in draft?"
  - If proceeding, select next sequential story in the current epic
  - If epic is complete, prompt user: "Epic {epicNum} Complete: All stories in Epic {epicNum} have been completed. Would you like to: 1) Begin Epic {epicNum + 1} with story 1 2) Select a specific story to work on 3) Cancel story creation"
  - **CRITICAL**: NEVER automatically skip to another epic. User MUST explicitly instruct which story to create.
- **If no story files exist:** The next story is ALWAYS 1.1 (first story of first epic)
- Announce the identified story to the user: "Identified next story for preparation: {epicNum}.{storyNum} - {Story Title}"

### 2. Gather Story Requirements and Previous Story Context

- Extract story requirements from the identified epic file
- If previous story exists, review Dev Agent Record sections for:
  - Completion Notes and Debug Log References
  - Implementation deviations and technical decisions
  - Challenges encountered and lessons learned
- Extract relevant insights that inform the current story's preparation

### 3. Gather Architecture Context

#### 3.1 Determine Architecture Reading Strategy

- Read `{architecture.indexFile}` (default `docs/architecture/index.md`) and follow the structured reading order below. MOSK v2 is sharded-only.
- Also check for feature-scoped architecture in `{specs.root}/{current_spec_id}/architecture/` (ADRs and data models specific to this spec).

#### 3.2 Read Architecture Documents Based on Story Type

The items below are **logical names**, not literal paths. To resolve each real file in `docs/architecture/`:

1. Prefer the links in `{architecture.indexFile}` when available.
2. If the index does not list the item, glob `docs/architecture/**/*<stem>.md` (numeric prefix like `1-`, `02-` is optional and should be ignored when matching).
3. If no file matches, record "No specific guidance found in architecture docs" and proceed.

Always cite with the real resolved path: `[Source: architecture/<actual-filename>.md#<section>]`.

**For ALL Stories:** `tech-stack`, `unified-project-structure`, `coding-standards`, `testing-strategy`

**For Backend/API Stories, additionally:** `data-models`, `database-schema`, `backend-architecture`, `rest-api-spec`, `external-apis`

**For Frontend/UI Stories, additionally:** `frontend-architecture`, `components`, `core-workflows`, `data-models`

**For Full-Stack Stories:** Read both Backend and Frontend sections above

#### 3.3 Extract Story-Specific Technical Details

Extract ONLY information directly relevant to implementing the current story. Do NOT invent new libraries, patterns, or standards not in the source documents.

Extract:

- Specific data models, schemas, or structures the story will use
- API endpoints the story must implement or consume
- Component specifications for UI elements in the story
- File paths and naming conventions for new code
- Testing requirements specific to the story's features
- Security or performance considerations affecting the story

ALWAYS cite source documents: `[Source: architecture/{filename}.md#{section}]`

### 4. Verify Project Structure Alignment

- Cross-reference story requirements with Project Structure Guide from `docs/architecture/unified-project-structure.md`
- Ensure file paths, component locations, or module names align with defined structures
- Document any structural conflicts in "Project Structure Notes" section within the story draft

### 5. Populate Story Template with Full Context

- Create new story file: `{specs.root}/{current_spec_id}/{specs.storiesSubdir}/{epicNum}.{storyNum}.story.md` using Story Template
- Fill in basic story information: Title, Status (Draft), Story statement, Acceptance Criteria from Epic
- **`Dev Notes` section (CRITICAL):**
  - CRITICAL: This section MUST contain ONLY information extracted from architecture documents. NEVER invent or assume technical details.
  - Include ALL relevant technical details from Steps 2-3, organized by category:
    - **Previous Story Insights**: Key learnings from previous story
    - **Data Models**: Specific schemas, validation rules, relationships [with source references]
    - **API Specifications**: Endpoint details, request/response formats, auth requirements [with source references]
    - **Component Specifications**: UI component details, props, state management [with source references]
    - **File Locations**: Exact paths where new code should be created based on project structure
    - **Testing Requirements**: Specific test cases or strategies from testing-strategy.md
    - **Technical Constraints**: Version requirements, performance considerations, security rules
  - Every technical detail MUST include its source reference: `[Source: architecture/{filename}.md#{section}]`
  - If information for a category is not found in the architecture docs, explicitly state: "No specific guidance found in architecture docs"
- **`Tasks / Subtasks` section:**
  - Generate detailed, sequential list of technical tasks based ONLY on: Epic Requirements, Story AC, Reviewed Architecture Information
  - Each task must reference relevant architecture documentation
  - Include unit testing as explicit subtasks based on the Testing Strategy
  - Link tasks to ACs where applicable (e.g., `Task 1 (AC: 1, 3)`)
- Add notes on project structure alignment or discrepancies found in Step 4

### 6. Story Draft Completion and Review

- Review all sections for completeness and accuracy
- Verify all source references are included for technical details
- Ensure tasks align with both epic requirements and architecture constraints
- Update status to "Draft" and save the story file
- Execute `.claude/mosk/tasks/execute-checklist.md` with
  `.claude/mosk/checklists/story-readiness-checklist.md`
- Provide summary to user including:
  - Story created: `{specs.root}/{current_spec_id}/{specs.storiesSubdir}/{epicNum}.{storyNum}.story.md`
  - Status: Draft
  - Key technical components included from architecture docs
  - Any deviations or conflicts noted between epic and architecture
  - Checklist Results
  - Next steps: For Complex stories, suggest the user carefully review the story draft and also optionally have the SM run the task `.claude/mosk/tasks/review-story-draft.md`
