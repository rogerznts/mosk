# shard-doc

Split a Markdown document by level-two sections without changing its content.

## Workflow

1. Resolve the source and canonical destination. The default destination is the
   source's parent directory; never write outside `docs/` without explicit user
   direction.
2. If `markdownExploder` is enabled and `md-tree` is already available, run
   `md-tree explode <source> <destination>`. Do not install packages or use the
   network automatically.
3. Otherwise shard manually:
   - parse `##` headings only outside fenced code blocks;
   - preserve all section content byte-for-byte except heading levels;
   - convert each section title to a collision-free kebab-case filename;
   - lower each heading level by one inside the shard;
   - create/update `index.md` with the original H1/introduction and ordered
     links to every shard.
4. Validate reversibility: section count, order, code fences, diagrams, tables,
   links and placeholders must match the source. Refuse ambiguous filename
   collisions instead of overwriting.
5. Report source, destination, files and validation result. Leave the original
   file untouched unless the user explicitly asks to remove it.

## Rules

- A `##` inside code or quoted example is not a section.
- Never summarize, rewrite or omit content.
- Preserve canonical `docs/prd/` and `docs/architecture/` layout.
