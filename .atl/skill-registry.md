# Skill Registry — Age of Acadia (ID0003)
Generated: 2026-07-25

## Convention Files

| File | Scope | Notes |
|------|-------|-------|
| `comfyui/AGENTS.md` | Submodule (ComfyUI) | Engineering style, architecture boundaries, code conventions for ComfyUI core. Not applicable to the project itself. |

## Installed Skills (User-Level)

| Name | Trigger | Path |
|------|---------|------|
| branch-pr | Creating, opening, or preparing PRs for review | `~/.config/opencode/skills/branch-pr/SKILL.md` |
| chained-pr | PRs over 400 lines, stacked PRs, review slices | `~/.config/opencode/skills/chained-pr/SKILL.md` |
| cognitive-doc-design | Writing guides, READMEs, RFCs, onboarding, architecture, or review-facing docs | `~/.config/opencode/skills/cognitive-doc-design/SKILL.md` |
| comment-writer | PR feedback, issue replies, reviews, Slack messages, or GitHub comments | `~/.config/opencode/skills/comment-writer/SKILL.md` |
| customize-opencode | Editing opencode's own configuration | `<built-in>` |
| go-testing | Go tests, go test coverage, Bubbletea teatest, golden files | `~/.config/opencode/skills/go-testing/SKILL.md` |
| issue-creation | Creating GitHub issues, bug reports, or feature requests | `~/.config/opencode/skills/issue-creation/SKILL.md` |
| judgment-day | Judgment day, dual review, adversarial review, juzgar | `~/.config/opencode/skills/judgment-day/SKILL.md` |
| sdd-apply | Implement SDD tasks from specs and design | `~/.config/opencode/skills/sdd-apply/SKILL.md` |
| sdd-archive | Archive a completed SDD change by syncing delta specs | `~/.config/opencode/skills/sdd-archive/SKILL.md` |
| sdd-design | Create the SDD technical design and architecture approach | `~/.config/opencode/skills/sdd-design/SKILL.md` |
| sdd-explore | Explore SDD ideas before committing to a change | `~/.config/opencode/skills/sdd-explore/SKILL.md` |
| sdd-init | Initialize SDD context, testing capabilities, registry, and persistence | `~/.config/opencode/skills/sdd-init/SKILL.md` |
| sdd-onboard | Walk users through the SDD workflow on the real codebase | `~/.config/opencode/skills/sdd-onboard/SKILL.md` |
| sdd-propose | Create an SDD change proposal with intent, scope, and approach | `~/.config/opencode/skills/sdd-propose/SKILL.md` |
| sdd-spec | Write SDD delta specs with requirements and scenarios | `~/.config/opencode/skills/sdd-spec/SKILL.md` |
| sdd-tasks | Break an SDD change into implementation tasks | `~/.config/opencode/skills/sdd-tasks/SKILL.md` |
| sdd-verify | SDD verification phase, verify change | `~/.config/opencode/skills/sdd-verify/SKILL.md` |
| skill-creator | New skills, agent instructions, documenting AI usage patterns | `~/.config/opencode/skills/skill-creator/SKILL.md` |
| skill-improver | Improve skills, audit skills, refactor skills, skill quality | `~/.config/opencode/skills/skill-improver/SKILL.md` |
| skill-registry | Update skills, skill registry, after skill changes | `~/.config/opencode/skills/skill-registry/SKILL.md` |
| work-unit-commits | Plan commits as reviewable work units | `~/.config/opencode/skills/work-unit-commits/SKILL.md` |

## Project-Level Skills

None detected. Scan paths checked:
- `skills/`, `.opencode/skills/`, `.claude/skills/`, `.gemini/skills/`
- `.cursor/skills/`, `.github/skills/`, `.codex/skills/`, `.qwen/skills/`
- `.kiro/skills/`, `.openclaw/skills/`, `.pi/skills/`, `.agent/skills/`
- `.agents/skills/`, `.atl/skills/`

## Registry Notes

- sdd-* skills, _shared, and skill-registry are excluded per SDD convention (listed here for reference only).
- Deduplication: user-level skills only (no project-level duplicates found).
- ComfyUI/submodule conventions are in `comfyui/AGENTS.md` — applicable when working inside `comfyui/`.
