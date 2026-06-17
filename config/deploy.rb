# frozen_string_literal: true

lock '~> 3.20.0'

server '167.71.44.132', port: 22, roles: %i[web app db], primary: true

set :application, 'ruby_coin'
set :repo_url,    'git@github.com:anko20094/ruby_coin.git'
set :branch,      'master'
set :user,        'root'

set :deploy_to, "/home/#{fetch(:user)}/apps/#{fetch(:application)}"
set :ssh_options, { forward_agent: true, user: fetch(:user), keys: %w[~/.ssh/id_rsa.pub] }
set :pty,          true
set :use_sudo,     false
set :stage,        :production
set :rails_env,    :production
set :deploy_via,   :remote_cache

# ------------------------------
# RBENV CONFIG
# ------------------------------
set :rbenv_type, :user
set :rbenv_ruby, '3.4.9'
set :rbenv_path, '/root/.rbenv'
set :rbenv_roles, :all
set :rbenv_map_bins, %w[rake gem bundle ruby rails]

# bundler
set :bundle_jobs, 4

# ------------------------------
# Puma configuration
# ------------------------------
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.access.log"
set :puma_error_log,  "#{release_path}/log/puma.error.log"
set :puma_preload_app,           true
set :puma_worker_timeout,        nil
set :puma_init_active_record,    true
set :puma_enable_socket_service, true
set :keep_releases,              5
set :conditionally_migrate,      true
set :puma_systemctl_user, :system

# ------------------------------
# Files and dirs persisted between deploys
# ------------------------------
append :linked_files, *%w[config/master.key config/database.yml config/credentials.yml.enc .env]

set :linked_dirs, %w[log tmp/pids tmp/cache tmp/sockets vendor/bundle public/uploads public/system node_modules]

# ------------------------------
# Yarn install before asset precompile
# ------------------------------
namespace :deploy do
  desc 'Install node packages via yarn'
  task :yarn_install do
    on roles(:web) do
      within release_path do
        execute :yarn, 'install'
      end
    end
  end
end

before 'deploy:assets:precompile', 'deploy:yarn_install'

# ------------------------------
# Upload credentials automatically
# ------------------------------
namespace :deploy do
  namespace :check do
    before :linked_files, :set_master_key do
      on roles(:app), in: :sequence, wait: 10 do
        files_to_upload = [
          { file: 'config/credentials.yml.enc' },
          { file: 'config/master.key' },
          { file: 'config/database.yml' },
          { file: '.env' }
        ]

        files_to_upload.each do |file|
          upload! file[:file], "#{shared_path}/#{file[:file]}" unless test("[ -f #{shared_path}/#{file[:file]} ]")
        end
      end
    end
  end
end
