# Image Prompt Templates

These templates convert a skill workflow or structure map into a prompt for Codex `imagegen` or the work-repo `images-generate` skill.

## Workflow Infographic

```text
Create a clean Japanese workflow infographic for the skill "{skill_name}".

Audience: Codex/Claude users who need to quickly understand when and how to use this skill.
Purpose: {purpose}
Aspect ratio: {aspect_ratio}
Format: operational workflow diagram, not a marketing poster.

Layout:
- Header: "{skill_name} の使い方"
- Left-to-right flow with {phase_count} phases
- Decision points shown as diamonds
- Approval gates shown with a clear warning accent
- Final output shown as a distinct end box

Diagram content:
{diagram_content}

Required Japanese labels:
{labels}

Visual style:
Clean documentation infographic, neutral background, high contrast, readable Japanese labels, compact but not crowded, restrained accent colors, no decorative AI motifs.

Avoid:
Tiny text, long paragraphs, vague robot imagery, mascot characters, abstract glowing backgrounds, crowded arrows, unreadable labels.
```

## Structure Infographic

```text
Create a clean Japanese structure infographic for the skill folder "{skill_name}".

Audience: maintainers who need to understand where workflow, references, scripts, and assets live.
Aspect ratio: {aspect_ratio}

Layout:
- Folder tree on the left
- Responsibility map on the right
- Bottom row showing "読み込み順" from metadata to SKILL.md to references/scripts

Content:
{structure_summary}

Visual style:
Precise technical infographic, readable Japanese labels, clear hierarchy, minimal color coding, no decorative clutter.
```

## Risk And Approval Infographic

```text
Create a Japanese risk map infographic for the skill "{skill_name}".

Audience: operator who needs to know what is safe to run automatically and what requires confirmation.
Aspect ratio: {aspect_ratio}

Layout:
- Safe read-only actions in one lane
- Draft and confirmation gates in the middle lane
- External write/send/delete actions in a warning lane
- Validation and post-action checks at the end

Content:
{risk_summary}

Visual style:
Operational safety diagram, clear warning accents, readable labels, no alarmist imagery.
```
