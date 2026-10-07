# RubyCoin

[![CI](https://github.com/anko20094/ruby_coin/actions/workflows/ci.yml/badge.svg)](https://github.com/anko20094/ruby_coin/actions/workflows/ci.yml)

The source of [rubyco.in](https://rubyco.in): a portfolio (`/work`, `/team`, `/cv`), a bilingual journal
(`uk`/`en`, always in the path) and its admin at `/management`. One Rails 8.1 monolith.

## Docs

* [`docs/architecture.md`](docs/architecture.md) — the stack and where each piece is configured.
* [`docs/decisions.md`](docs/decisions.md) — the decisions in force, one short entry each.
* [`docs/redesign_plan.md`](docs/redesign_plan.md) — the archive: how those decisions were reached.
* [`CLAUDE.md`](CLAUDE.md) — how to work here (commands and conventions), for people and assistants.

Where a doc and the code disagree, the code wins.

## Requirements

* Ruby 3.4.9 (`.ruby-version`)
* PostgreSQL 14 or newer (CI runs 14.10)
* Node.js 20.19 or newer (`sass` needs it; CI runs 22 LTS) and Yarn 4 — the release is pinned in
  `.yarn/releases` and `package.json`, so a global `yarn` of any version runs the right one
* ImageMagick (post covers, seeds; the specs that need it skip without it)
* Chrome or Chromium — only for `rake og:cards`

## Setup

```bash
# 1. a database role; the defaults below match config/database.yml.example and .env.example
sudo -u postgres createuser -d -P dev        # password: dev

# 2. config
cp config/database.yml.example config/database.yml
cp .env.example .env                         # optional: DB_* if your role is not dev/dev

# 3. dependencies and assets
bundle install
yarn install
yarn build && yarn build:css                 # bin/dev rebuilds them on change

# 4. database and seed data (cases from config/portfolio, an admin, sample journal entries)
bin/rails db:create db:schema:load db:seed

# 5. git hooks (RuboCop, Fasterer and bundler-audit before every commit)
bundle exec overcommit --install && bundle exec overcommit --sign
```

`db:seed` prints the admin's generated password. Set `SEED_ADMIN_EMAIL`, `SEED_ADMIN_PASSWORD` and
`SEED_ADMIN_NICKNAME` in `.env` to choose them (defaults: `admin@rubyco.in`, a random password, `danyil`).

## Run

```bash
bin/dev        # Rails on http://localhost:3000 plus the JS and CSS watchers (Procfile.dev)
```

Component previews (Lookbook): <http://localhost:3000/lookbook>, development only.

## Tests and lint

```bash
bundle exec rspec                    # the whole suite; CI runs exactly this
bundle exec rspec --tag ~slow        # skips the two specs that boot a subprocess
bundle exec rubocop
bundle exec fasterer
bundle exec bundler-audit check --update
```

The test database needs the same role: `RAILS_ENV=test bin/rails db:create db:schema:load`.
CI (`.github/workflows/ci.yml`) also checks that the migrations rebuild `db/schema.rb` exactly.

To skip an overcommit hook once: `SKIP=RuboCop git commit`.

## Data tasks

```bash
bin/rails team:check                 # validate config/portfolio/people.yml and team.yml; non-zero on a problem
bin/rails team:who                   # who is on the site, in what state, on which projects
bin/rails og:cards                   # re-render the share cards in public/og (needs Chrome/Chromium, CHROME_BIN)
bin/rails after_party:run            # pending one-off data tasks (lib/tasks/deployment)
DRY_RUN=1 bin/rails after_party:run  # the same, inside a transaction that is rolled back
bin/rails cleanup:editor_orphans     # list unreferenced journal blocks/editor images; DRY_RUN=0 deletes
bin/rails covers:rebuild IDS=3,7     # rebuild those post covers (all without IDS); non-zero if one fails
bin/rails cleanup:legacy_cover_versions  # list the old uploader's cover versions; DRY_RUN=0 deletes
```

Cases are edited in `/management`; the database is their source of truth. `after_party:import_cases`
only creates the cases from `config/portfolio/cases.yml` that the table lacks (`FORCE=1` overwrites).
The CV is `config/portfolio/cv.yml`, read as it is — there is nothing to import.

Re-render the share cards after changing a case's title, tagline or first figure, or the home page lede,
and commit `public/og` — `spec/requests/og_cards_spec.rb` fails on stale cards.

## Deploy

Capistrano (`Capfile`, `config/deploy.rb`), from `master`, to a single host:

```bash
bundle exec cap production deploy
```

It runs `yarn install` before asset precompilation, migrates, and runs the pending `after_party` tasks on
the new release before it goes live, so a failing data task stops the deploy with the old release still
serving. Because that old release is still serving from the same database and `public/uploads`, data tasks
only add and never delete what it reads.

After the first deploy of the new cover uploader (`after_party:recompress_post_covers`), once the new
release is live: re-run any covers it named with `bin/rails covers:rebuild IDS=…`, then
`bin/rails cleanup:legacy_cover_versions` to see the old versions and `DRY_RUN=0` to delete them. `config/master.key`, `config/database.yml`, the credentials and `.env` are linked files on the
server.
