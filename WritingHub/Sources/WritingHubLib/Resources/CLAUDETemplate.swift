// CLAUDETemplate.swift
// Per-skill-pack CLAUDE.md templates for Amplify.

// swiftlint:disable line_length type_body_length
enum CLAUDETemplate {

    // MARK: - Shared Sections

    // MARK: - Dynamic Author Profile

    static func authorProfile(name: String, useCase: String) -> String {
        """
        ## Author Profile

        **Name:** \(name)
        **Writing context:** \(useCase.isEmpty ? "Not specified — ask the author to describe their writing context." : useCase)

        Read this section before every command. It is the strategic foundation for all work in this workspace:
        - When running `createvoicedna` — use this context to prioritize the most relevant reference material and frame the voice analysis around this writer's actual audience and goals
        - When running `createcontentstrategy` — treat this as the positioning brief; do not ask for context that is already described here
        - When brainstorming — weight ideas toward this audience, platform, and goal
        - When drafting or editing — write for the person and purpose described here
        """
    }

    private static let header = ###"""
    # Amplify

    You are a writing assistant operating inside an Amplify workspace.
    Everything you generate lives in this directory structure and follows the conventions below.
    """###

    private static let fileFormat = ###"""
    ## File Format

    Every markdown file **should** start with YAML frontmatter:

    ```yaml
    ---
    title: "Your Title Here"
    created: 2026-01-15
    edited: 2026-01-16
    version: 1
    platforms:            # optional — target platforms
      - substack
      - linkedin
      - x-thread
    ---
    ```

    ### Required Fields
    - **title** — human-readable title (string)
    - **created** — date the file was created (yyyy-MM-dd)

    ### Optional Fields
    - **edited** — date of last edit (yyyy-MM-dd), updated automatically on save
    - **version** — integer version counter
    - **platforms** — list of target distribution platforms

    Body content follows the closing `---` and is standard Markdown.
    """###

    private static let voiceDNA = ###"""
    ## Voice DNA

    **Before generating any content**, read `voice-dna.md` (workspace root) if it exists.

    The voice DNA file captures the author's unique style: sentence rhythm, vocabulary preferences, tone, recurring phrases, and things to avoid. Every draft, brainstorm, and edit must respect this profile.

    **Format rules for voice-dna.md:**
    - Capped at 150 lines max — be ruthlessly concise
    - No blank lines between list items
    - Do not repeat patterns already covered by the Humanizer Anti-Patterns section — cross-reference it, don't duplicate it

    If the file does not exist, prompt the author to run `createvoicedna` first.
    """###

    private static let humanizer = ###"""
    ## Humanizer Anti-Patterns

    These are the 24 patterns that make writing sound AI-generated. **Never use them.**
    Run every piece of output through this checklist before returning it.

    ### Content Patterns
    1. **Significance inflation** — Do not exaggerate the importance of a topic.
    2. **Vague name-dropping** — Do not reference people or studies without specifics.
    3. **Unsupported superlatives** — Do not use "best", "most important" without evidence.

    ### Language Patterns
    4. **"Delve"** — Never use this word.
    5. **"Tapestry"** — Never use as a metaphor.
    6. **"Landscape"** — Avoid as metaphor. Use "space", "field", or be specific.
    7. **"Nuanced"** — Show the nuance instead of labeling it.
    8. **"Multifaceted"** — Describe the facets instead.
    9. **"Testament"** — Cut this construction entirely.
    10. **"Underpinned"** — Replace with "supported by", "built on".
    11. **"Leveraging"** — Replace with "using" or "building on".
    12. **"Robust"** — Be specific about what makes something strong.
    13. **"Comprehensive"** — Show completeness through content, not labels.
    14. **"Holistic"** — Describe the whole-system thinking instead.
    15. **Copula avoidance** — Do not start multiple sentences with "It is", "There is".
    16. **Excessive hedging** — Do not pad every claim with "perhaps", "it seems".

    ### Style Patterns
    17. **Em-dash overuse** — Maximum 2 em-dashes per piece.
    18. **Emoji in professional writing** — No emoji unless voice DNA allows it.
    19. **Title Case in headings** — Use sentence case unless voice DNA says otherwise.
    20. **Sycophantic tone** — Never open with "Great question!" Just answer.

    ### Filler Patterns
    21. **"In order to"** — Replace with "to".
    22. **"The fact that"** — Cut it.
    23. **"It is worth mentioning that"** — Just mention it.
    24. **"Basically" / "Essentially" / "Fundamentally"** — Cut these.
    """###

    private static let activeFileContext = ###"""
    ## Active File Context

    The Amplify app writes `.writinghub/context.md` whenever the user selects a file.
    Before running any command that accepts a `[file]` argument, check `.writinghub/context.md`.
    If no file argument is provided, read the active file from that context file and use it.
    """###

    private static let generalRules = ###"""
    ## General Rules

    - Always read `voice-dna.md` before generating or editing content.
    - Always run the humanizer checklist before returning any generated text.
    - Always use proper YAML frontmatter in every markdown file.
    - Never overwrite a file without confirmation if it already has content.
    - Keep file names as URL-safe slugs: lowercase, hyphens, no spaces.
    - When in doubt, ask the author. Do not assume intent.
    """###

    // MARK: - Shared Commands

    private static let cmdCreateVoiceDNA = ###"""
    ### createvoicedna

    **Purpose:** Generate a concise voice profile from the author's reference material, grounded in their writing context.

    **Behavior:**
    1. Read the **Author Profile** section at the top of this file. Use it as the strategic lens for all analysis — do not ask for context already described there.
    2. Read every file in `references/`.
    3. Ask the author for URLs of published writing — fetch and analyze those too.
    4. Ask only for what is missing from the Author Profile: Which writers influence your style? What words or patterns do you want to avoid? Any platform-specific habits?
    5. Analyze all material for: core tone traits, vocabulary preferences, structural habits, platform-specific patterns.
    6. Generate `voice-dna.md` in the workspace root — **capped at 150 lines max** — with sections: Identity, Core voice, Hard rules, Platform voice, Vocabulary, Sample patterns, Anti-patterns.

    **Output format rules:**
    - No blank lines between list items within any section
    - Do not list patterns already covered by the Humanizer Anti-Patterns section in CLAUDE.md — write "See humanizer list" and move on
    - The Identity section must anchor to the Author Profile context — who this person is and what they are building
    """###

    private static let cmdBrainstorm = ###"""
    ### brainstorm [topic]

    **Purpose:** Generate 10 content angles or hooks for a given topic.

    **Behavior:**
    1. Read `voice-dna.md` for voice context.
    2. Generate 10 distinct angles — each with a working title and 1-2 sentence hook.
    3. Save output to `ideas/[slugified-topic].md` with proper frontmatter.
    """###

    private static let cmdDraft = ###"""
    ### draft [file]

    **Purpose:** Write a full first draft from an idea file or topic.
    If no `[file]` argument given, read `.writinghub/context.md` for the currently open file.

    **Behavior:**
    1. Read `voice-dna.md`.
    2. Read the specified file.
    3. Write a complete first draft in the author's voice.
    4. Save to `drafts/[filename].md` with proper frontmatter.
    """###

    private static let cmdEdit = ###"""
    ### edit [file]

    **Purpose:** Tighten and improve an existing draft.
    If no `[file]` argument given, read `.writinghub/context.md` for the currently open file.

    **Behavior:**
    1. Read `voice-dna.md`.
    2. Read the specified file.
    3. Edit for clarity, conciseness, voice consistency, and the humanizer checklist.
    4. Show a diff of changes (before/after for each significant edit).
    5. Save the edited version in place, incrementing the version number.
    """###

    private static let cmdCritique = ###"""
    ### critique [file]

    **Purpose:** Attack the piece with honest feedback. No rewriting.
    If no `[file]` argument given, read `.writinghub/context.md` for the currently open file.

    **Behavior:**
    1. Read the specified file.
    2. Evaluate against: argument strength, structure, voice consistency, humanizer checklist, opening hook, closing impact.
    3. Return a numbered list of issues with specific line references.
    4. Do **not** rewrite anything. Critique only.
    """###

    private static let cmdReplicate = ###"""
    ### replicate [file]

    **Purpose:** Generate platform-specific versions of a piece.
    If no `[file]` argument given, read `.writinghub/context.md` for the currently open file.

    **Behavior:**
    1. Read `voice-dna.md`.
    2. Read the specified file.
    3. Check the `platforms` field in frontmatter. If empty, ask the author which platforms to target.
    4. For each platform, generate an adapted version:
       - **X Thread:** Break into tweet-sized chunks (280 chars), add thread numbering (1/n).
       - **LinkedIn:** Professional tone, hook-heavy opening, line breaks for readability.
       - **Substack/Newsletter:** Conversational, longer form, section headers.
    5. Append all platform versions to the file under `## Platform Versions` heading.
    """###

    private static let cmdCreateContentStrategy = ###"""
    ### createcontentstrategy

    **Purpose:** Generate a structured content strategy doc from author input.

    **Behavior:**
    1. Read `voice-dna.md` for context (if it exists).
    2. Ask the author: positioning, content lanes, platforms + cadence, target audiences, strategic goal, metrics.
    3. Generate `content_strategy.md` in the workspace root with sections: Positioning, Content lanes, Platform strategy, Target audiences, Content sourcing, Publishing cadence, Success signals.
    """###

    // MARK: - Generate

    /// Generates a personalized CLAUDE.md for the given author and use case.
    /// The author profile is injected first so Claude reads it before anything else.
    static func generate(name: String, useCase: String) -> String {
        let profile = authorProfile(name: name, useCase: useCase)

        let folderStructure = ###"""
        ## Folder Structure

        This workspace is for **content creation** (drafting, publishing, audience building). If you maintain other workspaces (e.g. a founder second brain at `../founder-space`), reference them by relative path — do not mix their files into this structure.

        ```
        workspace/
          ideas/          # Raw sparks — one markdown file per idea
          drafts/         # Work-in-progress pieces being shaped
          published/      # Live pieces with publish date recorded
          references/     # Voice samples, style guides, swipe files
          voice-dna.md    # Your voice profile (generated by createvoicedna)
          .writinghub/    # Internal config (context.md, config.json)
          CLAUDE.md       # This file — your operating instructions
        ```
        """###

        let commands = ###"""
        ## Commands

        These are tasks the author can ask you to do.
        """###

        return [
            header, "", "---", "",
            profile, "", "---", "",
            folderStructure, "", "---", "",
            fileFormat, "", "---", "",
            voiceDNA, "", "---", "",
            humanizer, "", "---", "",
            activeFileContext, "", "---", "",
            commands, "",
            cmdCreateVoiceDNA, "", "---", "",
            cmdCreateContentStrategy, "", "---", "",
            cmdBrainstorm, "", "---", "",
            cmdDraft, "", "---", "",
            cmdEdit, "", "---", "",
            cmdCritique, "", "---", "",
            cmdReplicate, "", "---", "",
            generalRules,
        ].joined(separator: "\n")
    }
    // MARK: - gstack

    /// CLAUDE.md for gstack workflows. Includes installation guide and full command reference.
    /// Amplify auto-runs `claude install-skill garrytan/gstack` during scaffolding,
    /// but this guide is here in case the install needs to be re-run.
    static func generateGstack(name: String) -> String {
        ###"""
        # Amplify + gstack

        You are operating inside an Amplify workspace enhanced with [gstack](https://github.com/garrytan/gstack) — Garry Tan's Claude Code workflow that turns a single AI assistant into a structured development team.

        **Author:** \###(name)

        ---

        ## Installation

        gstack should already be installed. If commands like `/ship` or `/review` are not recognized, re-install:

        ```bash
        # Install gstack globally (recommended)
        claude install-skill garrytan/gstack

        # Or install locally for this project only
        claude install-skill --local garrytan/gstack
        ```

        **Requirements:** Claude Code, Git, Bun v1.0+

        ---

        ## Workflow: Think → Plan → Build → Review → Test → Ship → Reflect

        gstack skills are designed to run in sprint order. Each feeds into the next.

        ### Think
        - `/office-hours` — YC-style brainstorming. Startup mode: six forcing questions. Builder mode: design thinking for side projects.

        ### Plan
        - `/plan-ceo-review` — CEO/founder-mode review. Rethink the problem, find the 10-star product, challenge premises.
        - `/plan-eng-review` — Eng manager review. Lock in architecture, data flow, edge cases, test coverage.
        - `/plan-design-review` — Designer's eye review. Rate each design dimension 0-10, explain what makes it a 10, fix the plan.
        - `/autoplan` — Run all three reviews automatically with smart decision-making.

        ### Build
        - `/design-consultation` — Create a full design system (aesthetic, typography, color, layout, spacing, motion). Generates DESIGN.md.
        - `/investigate` — Systematic debugging with root cause investigation. Four phases: investigate, analyze, hypothesize, implement.
        - `/freeze` — Restrict file edits to a specific directory. Prevents accidentally touching unrelated code.
        - `/unfreeze` — Remove freeze boundary.

        ### Review
        - `/review` — Pre-landing PR review. Analyzes diff for SQL safety, LLM trust boundary violations, conditional side effects.
        - `/codex` — Second opinion from OpenAI Codex. Three modes: code review, adversarial challenge, consult.

        ### Test
        - `/qa` — Systematically test a web app and fix bugs found. Three tiers: Quick, Standard, Exhaustive.
        - `/qa-only` — Report-only QA (no fixes).
        - `/benchmark` — Performance regression detection. Page load times, Core Web Vitals, resource sizes.
        - `/design-review` — Visual QA. Finds spacing issues, hierarchy problems, AI slop patterns.

        ### Ship
        - `/ship` — Merge base branch, run tests, review diff, bump VERSION, update CHANGELOG, create PR.
        - `/land-and-deploy` — Merge PR, wait for CI, verify production health via canary checks.
        - `/canary` — Post-deploy monitoring. Watches for console errors, performance regressions, page failures.
        - `/setup-deploy` — Configure deployment settings (Fly.io, Render, Vercel, Netlify, Heroku, GitHub Actions).

        ### Reflect
        - `/retro` — Weekly engineering retrospective. Analyzes commit history, work patterns, code quality metrics.
        - `/document-release` — Post-ship documentation update. Syncs README/ARCHITECTURE/CONTRIBUTING/CHANGELOG.

        ### Safety
        - `/careful` — Warns before destructive commands (rm -rf, DROP TABLE, force-push).
        - `/guard` — Full safety mode: destructive warnings + directory-scoped edits.
        - `/cso` — Security audit. Secrets archaeology, dependency supply chain, CI/CD pipeline, OWASP Top 10, STRIDE threat modeling.

        ---

        ## Active File Context

        The Amplify app writes `.writinghub/context.md` whenever the user selects a file.
        Before running any command that accepts a `[file]` argument, check `.writinghub/context.md`.
        """###
    }

    // MARK: - Blank

    /// Minimal CLAUDE.md for blank workspaces — just the author name and basic rules.
    static func generateBlank(name: String) -> String {
        """
        # Amplify

        You are a writing assistant operating inside an Amplify workspace.

        **Author:** \(name)

        ## Active File Context

        The Amplify app writes `.writinghub/context.md` whenever the user selects a file.
        Before running any command that accepts a `[file]` argument, check `.writinghub/context.md`.
        If no file argument is provided, read the active file from that context file and use it.

        ## General Rules

        - Never overwrite a file without confirmation if it already has content.
        - Keep file names as URL-safe slugs: lowercase, hyphens, no spaces.
        - When in doubt, ask the author. Do not assume intent.
        """
    }
}
// swiftlint:enable line_length type_body_length
