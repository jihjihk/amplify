# Writing Hub — Product Plan

*Last updated: 2026-02-26*

---

## 1. What Is This, Really?

**One-sentence pitch:** A local-first writing cockpit that turns scattered ideas into a consistent publishing rhythm — your voice, your files, AI as copilot, git as the backbone.

**The deeper insight:** The problem isn't writing — it's the *system around writing*. Ideas live in 6 places. Voice DNA lives in a Notion doc nobody references. Publishing is manual. There's no cadence, no accountability, no pipeline. Every existing tool solves one slice (Typefully = scheduling tweets, Jasper = generating copy, Notion AI = rewriting). Nothing owns the *full loop*: **capture → develop → write → review → publish → repeat**.

Writing Hub is a **content operating system for solo creators** — local files, git-synced AI collaboration, voice-aware drafting, and multi-platform publishing. It's opinionated about workflow, not about what you write.

---

## 2. Core User

**Primary:** Ji herself — and people like her. Second-time founders, indie hackers, and creator-operators who:
- Have things to say but publish inconsistently
- Already use AI tools but in a fragmented way
- Value owning their content (local files > cloud lock-in)
- Write long-form (Substack, blog) AND short-form (X, LinkedIn)
- Have a voice and want AI to *match* it, not replace it

**Not for:** Content mills, SEO farms, people who want AI to write *for* them. This is for people who write *with* AI.

**Persona name:** "The Thoughtful Builder" — has 50 draft ideas, publishes 2x/month instead of 2x/week, knows their voice but can't operationalize it.

**TAM reality check:** This is niche — and that's fine. The creator economy has ~50M people, but the "thoughtful builder" segment is maybe 500K–2M. Enough for a $5-20M ARR business if you nail it, not a VC-scale rocketship. Perfect for a bootstrapped/indie product.

---

## 3. Competitive Landscape

| Tool | What it does | Gap |
|------|-------------|-----|
| **Typefully** | Schedule/write tweets & LinkedIn | Social-only. No long-form. No voice DNA. Cloud-locked. |
| **Jasper** | AI copy generation with brand voice | Enterprise pricing ($49+/mo). Cloud. Marketing-focused, not creator-focused. |
| **Notion AI** | AI inside your existing docs | No publishing pipeline. Voice is bolted on. Not writing-first. |
| **Lex** | AI-native long-form editor | No multi-platform publish. No idea pipeline. No accountability. Stalled product. |
| **Moonbeam** | Long-form AI drafts | Template-heavy. No voice DNA. No publishing. |
| **Buffer/Hootsuite** | Social scheduling | No writing. No AI. Scheduling only. |
| **Obsidian + plugins** | Local markdown + community plugins | DIY assembly required. No AI voice. No publishing. |
| **Claude Code / Cursor** | AI coding in terminal | Power tool, not a writing workflow. No publishing integration. |

**The gap:** Nobody combines **local-first files + voice DNA + idea capture + writing pipeline + multi-platform publish + AI copilot via git**. The closest experience is "Obsidian + 5 plugins + Zapier + ChatGPT" — Writing Hub is that, but designed as one coherent thing.

**Unique moat:** The git-based AI collaboration model. Your AI agent lives on a server, reads your repo, knows your voice DNA, can draft while you sleep. You pull, review, edit, push. This is genuinely novel — nobody else is doing async AI writing collaboration over git.

---

## 4. MVP — The Smallest Thing That Proves It

**Core thesis to validate:** *Can a local folder + git + AI agent + voice DNA produce a publishing workflow that's better than the Notion/ChatGPT/manual patchwork?*

### MVP Features (Week 1-2 build)

1. **Local folder structure** — opinionated directory layout:
   ```
   writing-hub/
   ├── voice-dna.md          # Your writing voice profile
   ├── parking-lot/          # Raw ideas (one file each)
   ├── drafts/               # Work in progress
   ├── ready/                # Ready to publish
   ├── published/            # Archive
   ├── schedule.md           # Publishing cadence config
   └── .agent/               # Agent workspace & logs
   ```

2. **Git-synced AI agent collaboration** — private repo, OpenClaw agent on server side:
   - Agent can read `parking-lot/` ideas and develop them into `drafts/`
   - Agent references `voice-dna.md` for every generation
   - User works locally (VS Code, terminal, whatever), pushes/pulls
   - Git gives version history, diff review, branch-per-draft if needed
   - Way more token-efficient than Notion API calls — agent reads plain files
   - Async by nature: Ji pushes an idea at midnight, agent has a draft by morning

3. **Voice DNA file** — structured markdown that the agent always references:
   - Migrate Ji's existing voice DNA from Notion into `voice-dna.md`
   - Include: tone, sentence patterns, vocabulary preferences, examples of good/bad
   - Agent prompt always includes this as context

4. **Idea capture via messaging** — text a WhatsApp/Telegram number → idea lands in `parking-lot/`:
   - OpenClaw already has Telegram integration — just route "idea: ..." messages to create a file and git push
   - Each idea = one markdown file with timestamp, raw thought, optional tags

5. **Simple CLI tool** (`hub`) for local workflow:
   - `hub idea "AI will eat finance"` → creates parking-lot file
   - `hub status` → shows pipeline counts, next publish date, streak
   - `hub promote draft-name` → moves draft to ready/
   - `hub publish draft-name --platform substack,x` → publishes (v1: opens browser with content copied)

6. **Publishing nudge** — agent checks `schedule.md`, sends reminder via Telegram if cadence is slipping

### What's NOT in MVP
- Mac app (CLI + folder is fine for validation)
- Auto-publish to platforms (copy-paste is fine for 10 users)
- TikTok/Instagram
- Multi-user / team features
- Paid subscriptions
- Fancy onboarding (Wispr Flow style — save for v2)

---

## 5. Prototype Plan — What Ji Builds in 2 Weeks

### Week 1: Foundation

**Day 1-2: Repo & folder structure**
- Create the writing-hub template repo on GitHub (private)
- Write the opinionated folder structure + README
- Migrate Ji's voice DNA from Notion → `voice-dna.md`
- Set up OpenClaw agent access to the repo (SSH key, clone, cron pull)

**Day 3-4: Agent integration**
- Write agent instructions (AGENTS.md in the repo) for how to handle:
  - New ideas in `parking-lot/` → develop into outlines in `drafts/`
  - Draft feedback when Ji leaves comments (as markdown comments or a `feedback.md`)
  - Voice DNA adherence — always reference `voice-dna.md`
- Set up git push/pull automation (agent pulls every N minutes or on webhook)
- Test the loop: Ji drops an idea → agent picks it up → creates draft → Ji reviews

**Day 5: Idea capture**
- Configure OpenClaw Telegram bot to recognize "idea:" prefix
- Route to: create `parking-lot/YYYY-MM-DD-slug.md`, commit, push
- Test: text idea from phone → appears in repo within minutes

### Week 2: Workflow & Polish

**Day 6-7: CLI tool (`hub`)**
- Simple bash/python script, ~200 lines
- Commands: `idea`, `status`, `promote`, `list`
- `status` reads folder counts + `schedule.md` to show streak/cadence health

**Day 8-9: Publishing nudge + schedule**
- `schedule.md` format: desired cadence (e.g., "2x/week, Tue+Fri")
- Agent checks on heartbeat: if no `published/` file this week → Telegram nudge
- Nudge includes: "You have 3 drafts ready. Want me to polish one for tomorrow?"

**Day 10: Dogfood**
- Ji uses the system to write and publish her next Substack post
- Document friction points, missing features, what felt magic vs. clunky
- Write up the experience as content (meta!)

---

## 6. Monetization

**Phase 1 (MVP, months 1-3): Free / open source template**
- The folder structure + CLI + agent instructions are a free GitHub template
- Ji uses it, writes about it, gets feedback
- No revenue — this is validation

**Phase 2 (if validated, months 3-6): BYOK SaaS**
- Hosted version: user connects their GitHub repo + LLM API key
- Writing Hub manages the agent, scheduling, publishing integrations
- **Pricing: $15-25/mo** (BYOK model — user pays their own LLM costs)
- This is the sweet spot: cheaper than Jasper ($49), more than Typefully free tier
- Users who bring their own key feel ownership, lower churn

**Phase 3 (months 6+): Managed + marketplace**
- Managed tier with included AI credits: $39-49/mo
- Voice DNA marketplace — buy/sell writing style profiles
- Publishing analytics — what resonates, when to post
- Team tier for small content teams

**Why BYOK > subscription-with-credits:**
- Ji's users are technical, they already have API keys
- Gross margins are better (no LLM costs to eat)
- Users feel in control, not locked in
- Can still offer managed tier for less technical users later

**OAuth model** (for platform integrations):
- User authorizes Substack, X, LinkedIn via OAuth
- Writing Hub publishes on their behalf
- This is a v2 feature — MVP just copies to clipboard

---

## 7. Distribution — Finding the First 10 Users

**Ji IS user #1.** That's the unfair advantage. She's building for herself.

### Channels (ordered by expected ROI):

1. **"Build in public" on X and Substack** (week 1)
   - Ji tweets the prototype, the workflow, the before/after
   - "I built a writing system that turned my 50 scattered ideas into 2 posts/week"
   - @jihprobs already has an audience in AI x founder space

2. **Substack post: "My AI Writing System"** (week 2)
   - Product of Probability readers are exactly the target persona
   - Include the GitHub template link — free to try

3. **Indie Hackers / Hacker News** (week 2-3)
   - "Show HN: A local-first AI writing hub using git for human-AI collaboration"
   - The git-as-sync-layer angle is HN catnip

4. **Creator communities** (week 3-4)
   - Ship30for30 alumni, Write of Passage, Compound Writing
   - These are communities of exactly the "thoughtful builder" persona

5. **Personal outreach** (ongoing)
   - Ji knows founders who write. DM 20 of them with the template.
   - "Hey, I built this thing for myself, want to try it?"

**First 10 users goal:** All should be people Ji knows or can talk to directly. Optimize for feedback density, not user count.

---

## 8. Open Questions & Risks

### Product risks
- **"Is this just a fancy folder?"** — The magic has to be in the agent behavior, not the folder structure. If the AI collaboration doesn't feel 10x better than ChatGPT + copy-paste, it's not a product.
- **Git literacy barrier** — Target users are technical, but "git pull to see your draft" is still friction. Need to solve this for non-technical creators eventually (web UI, desktop app).
- **Voice DNA quality** — If the AI can't actually match your voice, the whole premise falls apart. Need to test this rigorously with Ji's own voice DNA.

### Technical questions
- **Webhook vs. polling for git sync?** — GitHub webhooks to trigger agent on push vs. cron polling. Webhooks are better but more setup. Start with polling (every 5 min).
- **Substack API?** — Substack doesn't have a public write API. Options: browser automation, email-to-publish, or manual. This is a known blocker for auto-publish.
- **X API costs** — Posting to X programmatically requires API access ($100/mo for basic). May need to start with "copy to clipboard + open X" flow.
- **Conflict resolution** — What if Ji and the agent edit the same file? Git handles this, but merge conflicts in markdown are annoying. Solution: agent always works in `.agent/` staging area, only promotes to `drafts/` when ready. Ji never edits `.agent/` files.

### Strategic questions
- **Open source or closed?** — The template should be open source (distribution). The hosted agent service should be closed (monetization). Classic open-core model.
- **Naming** — "Writing Hub" is generic. Needs a real name before launch. Ideas: Cadence, Inkwell, Pressroom, Draft Loop, Voiceprint.
- **Solo vs. team** — Start solo. Team features add complexity. If it works for one person, team is a natural expansion.
- **Platform risk** — Depends on X API, Substack (no API), LLM providers. Mitigated by local-first architecture — the files are always yours.

---

## 9. The One Thing to Do Tomorrow

**Set up the repo and do the first agent loop.**

1. Create `writing-hub` private repo
2. Add the folder structure
3. Copy voice DNA from Notion → `voice-dna.md`
4. Drop one idea in `parking-lot/`
5. Have OpenClaw agent read it and produce a draft outline
6. Review the draft

If that loop feels magic — if the draft actually sounds like Ji — then everything else is just packaging. If it doesn't, fix the voice DNA and agent prompts until it does. The entire product lives or dies on that loop.

---

---

## 10. Multi-Agent Writing Pipeline (added Feb 26)

The core differentiator vs. "just use Claude": Writing Hub has **specialized agents for each stage of the writing process**. You're not in a chatbox — you're switching modes.

### The 6 Agent Modes

| Mode | What it does | Trigger |
|------|-------------|---------|
| **Brainstorm** | Generates 10 angles, hooks, and related ideas from a seed concept. Surfaces connections to your existing published work. | `hub brainstorm parking-lot/idea.md` |
| **Research** | Finds data, studies, examples, and citations to support a thesis. Returns structured notes with sources. | `hub research drafts/draft.md` |
| **First Draft** | Writes a complete first draft in your voice DNA. Reads `voice-dna.md` every time, no exceptions. Never outputs generic prose. | `hub draft parking-lot/idea.md` |
| **Edit** | Tightens prose, fixes rhythm, enforces style guide. Short sentences where needed, varied length, kills AI vocabulary. Returns a red-line diff. | `hub edit drafts/draft.md` |
| **Critic** | Attacks the piece. Finds weak arguments, missing objections, logical gaps, unsupported claims. Returns a list of holes to fill — not a rewrite. | `hub critique drafts/draft.md` |
| **Replicate** | Takes a finished piece and reformats it for each platform: X thread, LinkedIn post, Substack intro hook, TikTok script, Instagram caption. Each has different tone/length norms baked in. | `hub replicate ready/piece.md --platforms x,linkedin,substack` |

### Why This Matters

Most AI writing tools are one mode: generate. You paste in a prompt and get a draft. Writing Hub separates the stages because the cognitive task is different at each stage:

- Brainstorming needs divergent thinking — generate many, evaluate none
- Researching needs accuracy over creativity — cite specifically, no hallucination
- Drafting needs voice fidelity — sound like Ji, not like a language model
- Editing needs ruthless compression — every sentence earns its place
- Critiquing needs adversarial thinking — steelman the objection, not the argument
- Replicating needs platform fluency — a tweet thread and a Substack post are different forms

One agent doing all six is like asking one person to be simultaneously the writer, editor, fact-checker, and critic. Specialization produces better output.

### Implementation in MVP

Start with two modes: **First Draft** and **Critic**. These are the highest-value and most differentiated.

- First Draft validates whether the voice DNA system actually works
- Critic validates whether the agent can improve a piece Ji already wrote

If both work, add Brainstorm and Edit in week 2. Replicate is a v2 feature (needs platform API integrations).

The mode switching can be as simple as different system prompts loaded per command. No complex orchestration needed in MVP — just well-crafted, specialized prompts plus the voice DNA file.

---

*This plan was generated as part of Ji's product brainstorming session. It's a living document — update as you build and learn.*
