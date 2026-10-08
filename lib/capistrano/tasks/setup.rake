# frozen_string_literal: true

namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "mkdir #{shared_path}/tmp/pids -p"
    end
  end

  before :start, :make_dirs
end

desc 'Make sure local git is in sync with remote.'
task :check_revision do
  on roles(:app) do
    # Update this to your branch name: master, main, etc. Here it's master
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts 'WARNING: HEAD is not the same as origin/master'
      puts 'Run `git push` to sync changes.'
      exit
    end
  end
end

desc 'Restart application'
task :restart do
  on roles(:app), in: :sequence, wait: 5 do
    invoke 'puma:restart'
  end
end

desc 'reload the database with seed data'
task :seed do
  puts "\n=== Seeding Database ===\n"
  on primary :db do
    within current_path do
      with rails_env: fetch(:stage) do
        execute :rake, 'db:seed'
      end
    end
  end
end

namespace :deploy do
  desc 'Run the pending data tasks against the new release'
  task :data do
    next unless fetch(:deploying)

    on primary :db do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'after_party:run'
        end
      end
    end
  end
end

desc 'Run after party'
task :after_party do
  on primary :db do
    within current_path do
      with rails_env: fetch(:stage) do
        execute :rake, 'after_party:run'
      end
    end
  end
end
