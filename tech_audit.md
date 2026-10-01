# Technology Audit: RubyCoin

The shape of the stack, for people and assistants who need to match the patterns already in the
repository. It names technologies and says where each one is configured. It does not pin
versions: `Gemfile.lock`, `package.json` and `.github/workflows/ci.yml` do that and cannot drift.

Where this file and the code disagree, the code wins. Decisions and their history live in
`redesign_plan.md`, where a later section beats an earlier one.

---

## 1. Runtime

| Layer | Technology | Where it is set |
| :--- | :--- | :--- |
| Language | Ruby 3.4.9 | `.ruby-version`, `Gemfile` |
| Framework | Rails 8.1 monolith on `rails/all`; Active Storage and Action Text are in use | `Gemfile`, `config/application.rb` |
| Database | PostgreSQL; CI runs 14.10 | `config/database.yml.example` (copy to the git-ignored `config/database.yml`) |
| Node.js | 20.19 or newer (`sass` requires it); CI runs Node 20 | `package.json`, `ci.yml` |
| Package manager | Yarn 4 (Berry), `nodeLinker: node-modules` | `package.json` (`packageManager`), `.yarnrc.yml` |
| Background jobs | ActiveJob on the in-process `:async` adapter. No Redis, Sidekiq or Solid Queue | `config/application.rb` |
| Cache | File store under `tmp/cache` in production | `config/environments/production.rb` |
| Locales | `uk` (default) and `en`, always in the URL path: `/(:locale)` | `config/routes.rb`, `config/application.rb` |

---

## 2. Backend

* **Authentication and authorization**: `devise` (custom `users/registrations` controller) and `pundit`
  with `pundit-matchers`. `/management` authenticates in `Management::ApplicationController`, and
  `verify_authorized` makes an action that never asked Pundit an error. Policies live in `app/policies`.
* **Where content is stored**
  * Post bodies: Action Text, one rich text per language (`description_en`, `description_uk`).
  * Post titles and subtitles: `mobility` on the Table backend (`post_translations`); fallbacks are off
    on purpose. See `config/initializers/mobility.rb`.
  * Cases and the CV: JSONB with `{ en:, uk: }` pairs, through the `LocalisedJson` and `StructuredJson`
    concerns. `Case` is edited in `/management`; the CV is `config/portfolio/cv.yml` imported by
    `rake cv:import`.
  * The team roster: YAML (`config/portfolio/people.yml`, `team.yml`) read by `Team`, `Person` and
    `Contribution`. There is no table and no admin screen for it.
* **Files**: `carrierwave` with MiniMagick for post covers (`PhotoUploader`); Active Storage on the Disk
  service for images inside post bodies (`Management::EditorImagesController`), with
  `variant_processor = :mini_magick`.
* **Search, URLs, paging, analytics**: `pg_search`, `friendly_id` (slug history keeps old URLs alive),
  `pagy`, and `ahoy_matey` with the statistics queries under `app/queries/statistics`.
* **Outbound HTTP**: `httparty`, used by `ChatgptService` for AI translation (`Posts::Translator`).
* **JSON**: `blueprinter` (`app/blueprints`, serving `/api/tags`).
* **Layers**: `BaseService.call` in `app/services`, `BaseQuery` in `app/queries`, `BaseValidator` in
  `app/validators`.
* **Data tasks**: `after_party` tasks in `lib/tasks/deployment` run after every deploy, so each one must be
  idempotent. `Cases::Importer` and `CV::Importer` copy the YAML in `config/portfolio` into the database
  and verify the round trip. `rake team:check` and `rake team:who` validate and print the roster.
* **Hardening**: `rack-attack` throttles (`config/initializers/rack_attack.rb`; off in development and
  test unless a spec turns it on), a Content-Security-Policy without a nonce
  (`config/initializers/content_security_policy.rb`), `Rack::Deflater` (`config/application.rb`), and
  `force_ssl` behind the `FORCE_SSL` variable.
* **Rich text rendering**: `rouge` highlights code blocks on the server and `nokogiri` reads the body
  (both in `JournalHelper`); the Action Text sanitizer allow-list is widened to what the editor can produce
  (`config/initializers/action_text.rb`).

---

## 3. Frontend

* **Templates**: `slim`, with `view_component` in `app/components`. Previews live in
  `spec/components/previews` and are served by Lookbook at `/lookbook` in development.
* **Public site**: `app/views/layouts/theme.html.slim`, styled by `theme.scss` (design tokens in
  `theme/_tokens.scss`, four self-hosted font families in `app/assets/fonts`) and scripted by
  `app/javascript/theme.js`: Stimulus controllers only, no Turbo.
* **Admin (`/management`)**: `app/views/management/layouts/application.html.slim`, scripted by
  `app/javascript/admin.js`, which loads `turbo-rails` with Turbo Drive switched off by decision (frames and
  streams only). It loads two stylesheets: `application.css` (Bootstrap 5 plus the old admin sheet
  `management.sass.scss`, still used by the screens that have not been re-skinned: cases and tags) and
  `admin.css` (the re-skin, loaded second).
* **Editor**: TinyMCE, self-hosted. `bin/copy_tinymce.mjs` copies it out of `node_modules` into the
  git-ignored `public/tinymce` on every `yarn build`, and `tinymce_controller.js` configures it. It edits the
  Action Text field; Trix is not part of the editor.
* **Pipeline**: Propshaft serves the assets. `jsbundling-rails` runs `esbuild` over `app/javascript/*.*`;
  `cssbundling-rails` runs `sass` over the four entry stylesheets named in `build:css`. There is no importmap.
  `bin/dev` starts `Procfile.dev`: the Rails server and the two watchers.

---

## 4. Testing and local quality

* **RSpec** (`rspec-rails`), transactional fixtures, with `factory_bot_rails`, `shoulda-matchers`,
  `pundit-matchers`, `faker`, `webmock` and `vcr` for outbound HTTP.
* **No system specs.** `capybara` is there for the matchers that the ViewComponent specs use, and no browser
  driver is configured (`spec/support/capybara.rb`).
* **RuboCop** with the performance, rails, rspec, rspec_rails, faker and factory_bot plugins
  (`.rubocop.yml`, 120 columns), **Fasterer** (`.fasterer.yml`) and **bundler-audit**.
* **Overcommit** runs those three before every commit (`.overcommit.yml`; `overcommit --sign` after a
  change to it).

---

## 5. CI/CD

* **`.github/workflows/ci.yml`**, on every push. Job `lint` runs RuboCop, Fasterer and bundler-audit. Job
  `test` runs only after it (`needs: lint`): PostgreSQL 14.10 on tmpfs, Node 20 with the Yarn cache, Ruby
  3.4.9, `yarn install`, `rails assets:precompile`, `db:create`, `db:schema:load`, `db:migrate`, then
  `bundle exec rspec`.
* **`.github/workflows/claude-review.yml`**: a pull-request comment that says `review` starts an automated
  code review.
* **Deploy**: Capistrano (`Capfile`, `config/deploy.rb`) to a single host over SSH. Puma runs under systemd
  behind nginx (`config/ruby_coin_puma_production.*`, `config/nginx.conf`) with rbenv. `yarn install` runs
  before asset precompilation and `after_party` after `deploy:published`. `master.key`, `database.yml`,
  the credentials and `.env` are linked files; `storage` and `public/uploads` are linked directories.
