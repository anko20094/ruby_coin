# CLAUDE.md

## How to work here

Commands (details and setup in `README.md`):

- Setup: `cp config/database.yml.example config/database.yml`, `bundle install`, `yarn install`,
  `bin/rails db:create db:schema:load db:seed`. Run: `bin/dev`.
- Build assets: `yarn build && yarn build:css` (the suite expects `app/assets/builds` and `public/tinymce`).
- Tests: `bundle exec rspec` (CI runs all of it; `--tag ~slow` skips the subprocess specs locally).
- Lint: `bundle exec rubocop`, `bundle exec fasterer`, `bundle exec bundler-audit check --update`.
- Roster: `bin/rails team:check` after any edit to `config/portfolio/people.yml` or `team.yml`.

Conventions:

- Views are Slim; anything shared is a ViewComponent in `app/components` with a spec and a Lookbook
  preview in `spec/components/previews`.
- JS: `app/javascript/theme/` (public), `admin/` (admin, incl. `admin/tinymce/`), `shared/` (both
  bundles), `lib/` (helpers). CSS entries are listed in `bin/build_css.mjs`; the admin has no Bootstrap.
- Content: cases live in the database (`cases.yml` only seeds missing ones, `FORCE=1` overwrites); the
  roster and every CV are YAML in `config/portfolio`, checked by `spec/content/`.
- `/management` authenticates in `Management::ApplicationController`, and `verify_authorized` runs after
  every action: each one asks Pundit (`authorize` / `policy_scope`), or it fails.
- Locale is always in the path, `/(:locale)` with `uk` (default) and `en`. Post titles are Mobility
  (Table backend, no fallbacks); post bodies are Action Text per language; cases are JSONB `{ en:, uk: }`.
  Every user-facing string is in both `config/locales/uk.yml` and `en.yml`.
- Turbo Drive is off: the public theme loads no Turbo at all, and `admin.js` sets
  `Turbo.session.drive = false` (frames and streams only). Don't rely on `data-turbo-method`.
- Data changes on production go through `after_party` tasks in `lib/tasks/deployment`, idempotent, with a
  spec. Delete a one-off task and its spec once it has run in production. The one exception: a backfill the
  same migration's schema change needs in order to apply — values a new unique index or `NOT NULL` is built
  over, or the copy of a column whose type changes — stays in that migration, in SQL (e.g.
  `AddEntryNumberToPosts`, `LocaliseCaseScalars`). Anything else goes in a task. Data tasks run while the old
  release still serves, so they only add; deleting what it reads is a manual task run after the deploy.
- No invented content: figures, names and CVs come from the machine or from the person.

## Project skills

- `mega-review` (`.claude/skills/mega-review/SKILL.md`) — exhaustive multi-agent pull-request review
  tuned to this Rails monolith. Use it when asked to "mega-review" a PR or to review one across all
  dimensions; for a quick single-pass look use `/code-review` instead.

## Project docs

- `docs/architecture.md` — the shape of the stack. Where it and the code disagree, the code wins.
- `docs/decisions.md` — the decisions in force, one entry each. Add a new decision there.
- `docs/redesign_plan.md` — the archive: how the decisions were reached. A later section beats an earlier
  one; the pointer at the top of the file names what is superseded.
