# Technology Audit: RubyCoin

This document provides a comprehensive technical audit of the **RubyCoin** codebase. It outlines the architectural patterns, backend/frontend stacks, database configurations, testing ecosystem, code quality tools, and CI/CD pipelines. 

This audit serves as a high-fidelity context for AI design and coding assistants (such as Claude) to ensure alignment with existing patterns, libraries, and design choices.

---

## 1. Core Architecture & System Stack

RubyCoin is structured as a modern, high-performance **Ruby on Rails monolith** with an integrated modern frontend.

| Layer | Technology / Version | Role / Implementation Details |
| :--- | :--- | :--- |
| **Language** | Ruby `3.4.9` | Defined in `.ruby-version` and `Gemfile`. |
| **Backend Framework** | Ruby on Rails `~> 8.1` | Monolith structure handling MVC, Routing, DB migrations, Job queues, and Asset compilation. |
| **Frontend Runtime** | Node.js `v18.15.0+` | Runs `esbuild` and `sass` compiler. |
| **Package Manager** | Yarn Berry `4.15.0` | Uses `nodeLinker: node-modules` (defined in `.yarnrc.yml`). |
| **Database** | PostgreSQL `15.2+` | Handles structured data storage. |
| **Key-Value Store** | Redis | Powering Sidekiq background jobs. |
| **CI/CD Platform** | GitHub Actions | Configured via `.github/workflows/ci.yml` (migrated from CircleCI). |

---

## 2. Backend Stack & Gems

### Core Features & Integrations
* **Authentication**: `devise` (handles user registration, session management, secure login).
* **Authorization**: `pundit` (`~> 2.5`) with RSpec integration via `pundit-matchers`. Implements fine-grained access control using policies.
* **Pagination**: `pagy` (`~> 43.2`) — ultra-fast, memory-efficient pagination.
* **Rich Text Editing**: `tinymce-rails` (`~> 8.3`) — integrated rich text editor for content management.
* **File Uploads**: `carrierwave` (`~> 3.1`) — handles secure file uploads and image processing.
* **Outbound HTTP**: `httparty` — lightweight HTTP client for external API integrations.
* **Serialization**: `blueprinter` — fast JSON serialization used for API endpoints.
* **Database Task Management**: `after_party` — manages post-deployment data migration scripts.

### Database & Search
* **Database Driver**: `pg` (`~> 1.6`) for PostgreSQL.
* **Full-Text Search**: `pg_search` (`~> 2.3`) — leverages PostgreSQL's full-text search features directly in ActiveRecord.
* **SEO-Friendly URLs**: `friendly_id` (`~> 5.6`) — replaces database IDs in URLs with customizable, human-readable slugs.
* **Internationalization (i18n)**: 
  * `globalize` (`~> 7.0`) for translating model attributes (storing multiple languages in database).
  * `rails-i18n` for handling standard Rails locale translations.

### Background Jobs & Performance
* **Background Queue**: `sidekiq` — Redis-backed asynchronous job processor.
* **Caching & Performance**: `bootsnap` (pre-compiles Ruby code for faster boot times) and `redis`.

---

## 3. Frontend & Styling Stack

RubyCoin uses a modern **Hotwire + Bundling** setup, bypassing complex single-page-app (SPA) frameworks while maintaining high interactivity.

### Template & Markup
* **Slim Templates**: `slim` — lightweight, elegant alternative to ERB, used for HTML templates.

### Reactive UI & Component Stack
* **Hotwire**: 
  * `turbo-rails` (`~> 2.0`) — handles lightning-fast, SPA-like navigation and real-time updates via Turbo Frames and Turbo Streams.
  * `stimulus-rails` — modular JavaScript controllers bound directly to HTML templates.

### Bundling & Asset Compilation
* **JS Bundling**: `jsbundling-rails` using **`esbuild`** (`^0.28.0`). Compiles modern JavaScript files in `app/javascript/`.
* **CSS Bundling**: `cssbundling-rails` using **`sass`** (`^1.100.0`). Compiles custom stylesheets starting from Bootstrap's core.

### UI & Styling Libraries
* **CSS Framework**: **Bootstrap 5.3** (`bootstrap` `^5.3.8`) for modern responsive layouts.
* **Icons**: `bootstrap-icons` (`^1.13.1`) and `@fortawesome/fontawesome-free` (`^7.2.0`).
* **Interactive UI components**: 
  * `bootstrap5-toggle` (`^5.3.3`) for custom toggles.
  * `tom-select` (`^2.6.1`) for rich, dynamic autocomplete and select inputs.
* **Analytics**: `ahoy_matey` (`~> 5.4`) for analytics and event tracking, combined with `groupdate` for time-series aggregation.
* **Charts**: `chartkick` (`~> 5.2`) for visual data reporting.

---

## 4. Testing & Local Quality Ecosystem

RubyCoin enforces strict testing and code style rules before commits can be made and before CI runs.

### Local Git Hooks (`overcommit`)
* Configured via `.overcommit.yml` with version `~> 0.69.0`. 
* Enforces linters to pass before letting developers commit.

### Testing Stack
* **Test Suite**: `RSpec` (using `rspec-rails` `8.0.4`).
* **Factory Setup**: `factory_bot_rails` (`~> 6.5`) for clean mock object setup.
* **UI/System Testing**: 
  * `capybara` for interacting with headless browsers.
  * `selenium-webdriver` (`4.44.0`) configured to use headless Chrome (`:selenium_headless` driver in `spec/support/capybara.rb`). Selenium Manager handles Chromedriver versioning automatically.
* **Mocks & Stubbing**: 
  * `webmock` (`~> 3.26`) for intercepting outbound HTTP requests.
  * `vcr` (`~> 6.3`) for recording and replaying external HTTP requests (stored in `spec/fixtures/vcr_cassettes`).
* **Assertions & Fixtures**: 
  * `shoulda-matchers` for expressive database model and validation tests.
  * `database_cleaner` for resetting database state between test runs.
  * `faker` for generating realistic fake data.

### Static Code Analysis & Security
* **RuboCop** (along with `rubocop-rails`, `rubocop-rspec`, `rubocop-rspec_rails`, `rubocop-performance`, `rubocop-factory_bot`, `rubocop-faker`) — strict ruby linter. Configured in `.rubocop.yml`.
* **Fasterer** (`~> 0.11.0`) — static performance analysis suggesting speed improvements based on fast Ruby idioms. Configured in `.fasterer.yml`.
* **Bundler Audit** (`~> 0.9.1`) — scans Gemfile.lock for known security vulnerabilities.

---

## 5. CI/CD Workflow (GitHub Actions)

Continuous Integration is handled via **GitHub Actions** (`.github/workflows/ci.yml`) and is optimized to run two jobs in parallel:

1. **`lint` (Fast Code Audit)**:
   * Boots lightweight runner, sets up Ruby `3.4.9` with Bundler caching.
   * Runs `rubocop`, `fasterer`, and `bundler-audit` to detect style, speed, or security issues instantly.
2. **`test` (System & Integration Tests)**:
   * Sets up a **PostgreSQL 14** service container mapped to memory (`tmpfs`) for extreme database operations performance.
   * Sets up **Node.js 20** with Yarn Berry cache and **Ruby 3.4.9** with Bundler cache.
   * Installs frontend packages (`yarn install`), precompiles assets (`bundle exec rails assets:precompile`), initializes/migrates the test database, and runs the entire RSpec suite.
