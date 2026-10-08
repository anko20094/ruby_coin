---
name: mega-review
description: >-
  Exhaustive, multi-dimensional pull-request review for this Rails 8 monolith (Slim, ViewComponent,
  Hotwire, Pundit, Mobility, uk/en locale in the path). Runs a parallel fan-out of dimension
  reviewers (spec, security, data-safety/concurrency, persistence, logic, architecture & i18n,
  tests, frontend/views), adversarially verifies every High/Critical finding, de-duplicates,
  calibrates severity, and posts grouped inline GitHub review comments + a summary with a merge
  gate. Use when the user asks to "mega-review", "/mega-review", do a "повне/глибоке рев'ю ПР",
  "thoroughly review this PR", or review a PR across all dimensions. NOT for a quick single-pass
  look — that is /code-review.
---

# mega-review — exhaustive PR review

A 7-phase pipeline that reviews a PR across every dimension, then posts precise, verified,
de-duplicated findings to GitHub. Context: a **Rails 8.1 / Ruby 3.4 monolith** (`ronico-ua/ronico`,
trunk `master`) — public site + `management` admin, bilingual (`uk`/`en`) with the locale in the URL
path, server-rendered with Slim + ViewComponent + Turbo/Stimulus (esbuild/sass), Devise + Pundit,
Mobility translations, FriendlyId slugs, Ahoy analytics, Rack::Attack, CarrierWave uploads, Postgres
(`pg_search`), `after_party` data tasks. Unless the diff says otherwise.

The single most important property: **find → adversarially verify → synthesize**. Finder agents
over-report; an unverified finding is not allowed to ship as High/Critical. Quality > quantity.

---

## Phase 0 — Invocation, level, gate

1. **Target**: the PR number from args, else the PR for the current branch (`gh pr view --json number`).
2. **Level**: `quick` | `standard` | `ultra`. **Default = `ultra`**, and you MUST tell the user:
   *"No level specified — running the maximum (ultra) of three (quick/standard/ultra)."*
   - `quick`: one finder, lenses 1+2+7 (spec/security/tests), verify Critical only, summary only.
   - `standard`: lenses 1–6, verify High+Critical, inline + summary.
   - `ultra`: all activated lenses, adversarial-verify all High/Critical, completeness critic.
3. **Posting gate (ASK)**: *"May I post inline review comments to GitHub? They will be in English,
   concise — problem + suggested fix (with a code snippet where useful)."* Options:
   **post / dry-run (show, don't post) / summary-only**. Honour the answer in Phase 5.
4. **Resolve**: head SHA (`gh pr view <n> --json headRefOid`); base = **merge-base of the PR's base
   branch and head** (`git merge-base origin/<baseRefName> <head>`; usually `master`). If the base is
   itself another open PR (stacked), record it for cross-PR dedup in Phase 4.

## Phase 1 — Context & surface profiling

1. PR metadata + body → linked issue/ticket, plus any plan the PR follows (`redesign_plan.md`,
   `design_handoff_rubycoin_site/`, `tech_audit.md`). Fetch the issue and comments if linked.
2. **Extract checkable invariants** — turn every "must do X / behaves like Y" into a spec checklist
   line (redirects that must keep indexed URLs alive, locale parity, canonical URLs, sitemap entries).
   In `redesign_plan.md` a later section wins over an earlier one; the pointer at the top of the
   file names the superseded sections, and a row they cover is not an invariant.
3. Read **`CLAUDE.md`, `README.md`, `tech_audit.md`, `.rubocop.yml`, `.overcommit.yml`,
   `.github/workflows/ci.yml`** and the sibling files of every changed file → the *actual* conventions.
4. Compute the diff vs base; build a **file-area map**. Classify presence of: `app/views` +
   `app/components` (Slim/ViewComponent), `app/javascript` + `app/assets` (Stimulus/Turbo/SCSS),
   `db/migrate`, `app/models`, `app/controllers` (public / `management` / `api`), `app/policies`,
   `app/services` + `app/queries` + `app/validators`, `config/locales`, `config/routes.rb`,
   `lib/tasks` + `after_party`, `spec/**`.
5. **Surface profiling → activate lenses.** A lens with no surface does NOT run (and you say so).
6. **Blast-radius ranking**: authorization (Pundit/Devise/`management`) / migrations / routes &
   redirects of indexed URLs / uploads / the admin editor / outbound HTTP (`ChatgptService`,
   importers) = *high*; public view markup and copy = *medium*; cosmetic = *low*.
7. Output a **review brief**: { invariants, conventions, activated lenses, diff map, blast ranking,
   stacked-base? } — fed verbatim into every finder.

**Sandbox caveat.** This repo is a training ground: sibling code is evidence of local habit, not of
correctness. "Neighbours do it this way" never justifies a pattern on its own — when a finding or a
non-finding rests on a convention, say whether it is *idiomatic Rails*, *acceptable*, or a *local
quirk*, and ground it in the framework's behaviour or docs.

## Phase 2 — Finder fan-out (~8 grouped agents, parallel)

Spawn the finders **in parallel** (one message, multiple subagents; or a Workflow if available). Each
agent OWNS its questions; if it spots something owned by another lens, it adds a one-line tag for that
owner and does **not** write it up. This ownership matrix is the anti-duplication core.

| Agent | Lens it OWNS | Does NOT touch | Rails notes |
|---|---|---|---|
| **1. Spec & soundness** | Does the code satisfy each invariant? Right *approach* for the existing architecture; no regression of existing behaviour | impl micro-details (→#5), style | indexed URLs keep resolving (`/post/:id`, `/search`, FriendlyId history), both locales |
| **2. Security** | authz on **every** action (`authorize` / `verify_authorized`, `management` gating, `policy_scope`), strong params / mass assignment, IDOR, XSS (`html_safe`, `raw`, `sanitize`, TinyMCE output), SQL injection (`where("…#{}")`, `pg_search`), open redirects (locale/`return_to`), CSRF, CarrierWave content-type/extension allow-lists, secrets in repo/credentials, `Rack::Attack` coverage of new public POSTs, Devise config | perf, style | admin-only routes behind a policy; user-supplied HTML on public render |
| **3. Data-safety / concurrency** | transactions, races/TOCTOU (slug uniqueness, find-or-create), idempotency of importers (`Cases::Importer`, `CV::Importer`) and rake/`after_party` tasks, retries, partial failure, outbound HTTP timeouts & error handling | indexes (→#4) | `ChatgptService` / `HTTParty` calls without timeout; tasks that are not re-runnable |
| **4. Persistence** | migration order/safety (`algorithm: :concurrently`, `disable_ddl_transaction!`, reversible), **DB constraint ↔ model validation ↔ NULL semantics** mirroring, `schema.rb` drift, FK/cascade, **N+1 & missing indexes** (`includes`, `strict_loading`, view-level queries), Mobility columns/backend consistency, `pg_search` scopes | business logic | back-dated migrations, data changes inside schema migrations (belongs in `after_party`) |
| **5. Logic & failure modes** | happy/edge/error paths work; nil/blank; `rescue` specificity; state holes; `params[:locale]` handling and fallbacks; pagination edges (Pagy); empty states; 404 vs 500 (`ErrorsController`) | perf (→#4), style | missing translation for one locale; missing slug history; bad `Accept`/format |
| **6. Architecture, style & i18n** | layer placement (fat controller/model, logic in views/components), `BaseService.call` / `BaseQuery#all` / `BaseValidator` usage, Pundit for authz, Blueprinter for JSON, ViewComponent vs partial, **wire-or-omit / dead code**, naming, DRY; **i18n**: hardcoded user-facing strings, **`uk`/`en` key parity** in `config/locales`, missing keys, Mobility attributes for content; RuboCop/Fasterer would-fail items; the global comment rule (no narrated history, no restating code) | perf (→#4), correctness (→#5) | `raise_on_missing_translations` is off, so a missing key renders silently — flag it |
| **7. Tests** | coverage adequacy AND **"tests that lie"**: does the spec exercise the real production path, or fake the precondition / stub the thing that differs in prod? positive + negative; Pundit specs (`pundit-matchers`) for every new policy; component specs + Lookbook previews for new components; request/controller specs per locale; factories realistic | — | specs that sign in with a stub, stub `I18n`, or bypass `authorize` |
| **8. Frontend & views** *(only if views/JS/SCSS touched)* | Slim/ViewComponent correctness, Turbo (frames/streams, `data-turbo` opt-outs, cache), Stimulus controller lifecycle (`connect`/`disconnect`, targets, values, leaked listeners), `html_safe`/`raw` sinks (cross-check #2), accessibility (alt text, landmarks, focus, contrast, `lang` attribute), SEO (title/meta/canonical/`hreflang` for both locales, OG cards), asset pipeline (propshaft/esbuild/sass) | backend | one canonical URL per page per locale; no layout shift on images |

> **Dedup rule**: N+1/perf → **only #4**; structural placement and style → **only #6**; correctness →
> **only #5**; XSS sinks → **#2** (#8 tags them). One symptom → one owner.

Each finding uses the **finding schema** below, with accurate `path:line` verified via
`git show <head>:<path> | grep -n`.

## Phase 3 — Adversarial verify

For every **High/Critical** (and any contested) finding, spawn an independent **skeptic** whose job is
to *refute* it by re-reading the actual code + the relevant invariant. Verdict ∈
`confirmed | false-positive | needs-context | downgrade`, with a citation. Where a claim is about
framework behaviour (Turbo, Pundit, Mobility, ActiveRecord), the skeptic checks the gem source or the
official guide, and where cheap, runs it (`bin/rails runner`, `bundle exec rspec <file>`). Only
`confirmed` survives at its severity. Do not skip this at `ultra`/`standard`.

## Phase 4 — Synthesis, dedup, calibrate, gate

- **Dedup** by `(file:line, root-cause)`; keep the owning lens's write-up.
- **Cross-PR dedup**: if the base is another open PR, drop or annotate findings that PR already fixes
  (verify against that PR's diff, don't assume).
- **Severity rubric**: Critical (data loss / security breach / broken prod for many) · High (likely bug /
  serious gap) · Medium (real but bounded) · Low (style/nit). Every finding answers
  *"what would make this NOT a finding?"*.
- Weight by **blast radius**.
- **Anchor classification**: bug in changed code → `inline`; bug in an **untouched** file the diff merely
  relies on → `summary` (GitHub can't anchor inline on non-diff lines).
- Build the **must-fix gate list** (merge blockers) separate from nice-to-haves.
- Run the CI trio locally on the head when feasible and report failures as gate items:
  `bundle exec rubocop <changed files>`, `bundle exec fasterer`, `bundle exec bundler-audit check`.

## Phase 5 — Output & posting

Comment language is **English** (chat with the user in their language). Posting mode = the Phase-0 answer.

**Inline comment format** (concise):
```
**[Severity] <one-line title>.** <1–2 sentence problem, citing the mechanism>. <Suggested fix; include a
short code example when it makes the fix unambiguous>.
```

**Anchoring constraints** (avoid 422s):
- A line is anchorable only if it is part of the diff hunk. **New files → every line is in the diff.**
  Modified files → only changed/context lines; verify with `git diff <base> <head> -- <file>`.
- Findings on untouched files go into the summary body, not inline.

**Posting mechanics** (`gh api`, repo `ronico-ua/ronico`):
- One review with inline comments:
  `gh api --method POST repos/ronico-ua/ronico/pulls/<n>/reviews --input review.json`
  where `review.json` = `{ commit_id, event: "COMMENT"|"REQUEST_CHANGES", body, comments: [{path,line,side:"RIGHT",body}] }`.
  If any line is unanchorable the whole call 422s — fix that comment and retry.
- Edit a comment: `gh api -X PATCH repos/ronico-ua/ronico/pulls/comments/<id> -F "body=@file"`.
- Delete a comment: `gh api -X DELETE repos/ronico-ua/ronico/pulls/comments/<id>`.
- If a stray empty pending review blocks posting, submit it with your body:
  `gh api --method POST .../reviews/<id>/events -f event=COMMENT -F "body=@file"`.
- Write `review.json` and body files to the scratchpad, never into the repo.

**Grouping**: small/medium PR → one review; large PR → multiple logically-grouped reviews (e.g.
"security & data-safety" / "views & i18n" / "structure & tests"). Each review body carries the
**must-fix gate**, then **summary-only** items, then **"Done well"** (always — keep it balanced), then
a **completeness note** (which lenses ran, what was truncated — never silently truncate).

**Never credit the assistant** in anything posted or committed: no "Generated with Claude Code", no
co-author trailer, no mention in review bodies.

**Verdict / gate**: if any **Critical** survived → `REQUEST_CHANGES`; else `COMMENT`. State the verdict
to the user.

## Phase 6 — Completeness critic

A final pass: which activated lens returned suspiciously little? which High is unverified? what was
dropped by a cap? Either run a short follow-up round or disclose it honestly. Then report back to the
user: finding counts by severity, review links, the gate verdict, and the recommended next step.

---

## Finding schema (every agent emits this)

```
severity     : Critical | High | Medium | Low
lens         : 1..8                      # for dedup ownership
path:line    : <file>:<line>             # verified on head
code_excerpt : the offending line(s)
spec_clause  : <quote>                   # for spec issues
problem      : 1–2 sentences (the mechanism, not vibes)
suggested_fix: short; code example/snippet when it disambiguates
not_a_finding_if: <the false-positive guard>   # Phase 3 fills/checks this
blast_radius : high | med | low
anchor       : inline | summary
convention   : idiomatic | acceptable | local-quirk   # only when the finding rests on a convention
```

## Hard rules

- **Evidence or it doesn't ship**: file:line + code excerpt (+ spec clause for spec issues). No "looks bad".
- **No unverified High/Critical** — Phase 3 is mandatory at standard/ultra.
- **English** for everything posted to GitHub. The chat with the user follows their language.
- **Conventions from the docs, config and sibling files, not memory** — and never as the sole argument
  (see the sandbox caveat). Don't invent rules the repo doesn't hold.
- **Don't review** lockfiles (`Gemfile.lock`, `yarn.lock`), `node_modules`, `vendor`, `public/` build
  output, `storage/`, `log/`, or `schema.rb` line-by-line (use it to detect drift).
- **Adaptive**: never run the frontend lens with no views/JS; never flag "missing migration" on a no-DB PR.
- **Balanced**: always include genuine "Done well" notes.

---

## Appendix — pattern catalog (REFERENCE, not a goal)

Do **not** hunt for patterns or suggest one without a concrete symptom. Use this only to name the right
fix for a symptom you already found:

- god-controller / mixed responsibilities → **Service Object** (`BaseService.call`, one private `#call`)
- complex or reused query inline in a controller/model → **Query Object** (`app/queries/`, `BaseQuery#all`)
- ad-hoc `if current_user.admin?` → **Policy Object** (Pundit, `app/policies/`, `verify_authorized`)
- pure input checks → **Validator** (`app/validators/`, `BaseValidator`)
- JSON shaping → **Serializer** (Blueprinter, `app/blueprints/`)
- repeated markup + logic in views → **ViewComponent** (`app/components/`, with a spec and a Lookbook preview)
- view-only formatting in a model → **Helper** or component, not the model
- translated content → **Mobility** attribute; UI chrome → `I18n.t` key in both `uk.yml` and `en.yml`
- human-readable URLs → **FriendlyId** (with slug history for anything already indexed)
- one-off data change after deploy → **`after_party`** task, not a migration
- JS behaviour on markup → **Stimulus** controller (targets/values, cleanup in `disconnect`), not inline script
- partial page update → **Turbo Frame/Stream**, not hand-rolled fetch + innerHTML
- external HTTP → one wrapper class with timeouts and a defined failure mode

Principles to check against: **SRP**, DRY, skinny controllers/models + service layer,
convention-over-configuration, separation of concerns (controller → service → model; queries,
policies, validators, components separate), Law of Demeter (`delegate`), single source of truth.
