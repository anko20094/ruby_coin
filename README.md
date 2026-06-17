# RubyCoin

[![CI](https://github.com/anko20094/ruby_coin/actions/workflows/ci.yml/badge.svg)](https://github.com/anko20094/ruby_coin/actions/workflows/ci.yml)

Preinstallation
--------------
### PostgreSQL setup

1. Install postgresql if you don't have it
2. Create a `dev` user: `sudo -u postgres createuser -d -W dev` and enter password `dev`
3. Install nodeJS v18.15.0 or higher

Installation
--------------
1. git clone git@github.com:anko20094/ruby_coin.git
2. Run `bundle install`
3. Run `overcommit --install`
4. Run `overcommit --sign`
5. Run `yarn`
6. Run `rails db:create db:migrate db:seed`

Start server
--------------
1. To start a web server please run `bin/dev` or `s.cmd` if windows
2. Open [http://localhost:3000/](http://localhost:3000/) in your browser

### Stack of technologies
* Ruby       3.4.9
* Rails      8.1
* PostgreSQL 15.2
* Node.js    18.15.0 or higher
* Yarn       4.15.0

Testing & Quality Control
--------------
You can run the same linting and test suites locally before pushing to GitHub:

* **Run all tests (RSpec):**
  ```bash
  bundle exec rspec
  ```
* **Run RuboCop (Code style linter):**
  ```bash
  bundle exec rubocop
  ```
* **Run Fasterer (Ruby performance analyzer):**
  ```bash
  bundle exec fasterer
  ```
* **Run Bundler Audit (Gem security check):**
  ```bash
  bundle exec bundler-audit check --update
  ```

### How to skip `overcommit` (only if very needed):
`SKIP=RuboCop git commit`
