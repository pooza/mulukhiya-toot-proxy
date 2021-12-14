module Mulukhiya
  extend Rake::DSL

  namespace :bundle do
    desc 'install bundler'
    task :install_bundler do
      sh 'gem install bundler'
    end

    desc 'install gems'
    task install: [:install_bundler] do
      sh 'bundle install --jobs 4 --retry 3'
    end

    desc 'update gems'
    task update: [:install_bundler] do
      sh 'bundle update --jobs 4 --retry 3'
    end

    desc 'check gems'
    task :check do
      unless Environment.gem_fresh?
        warn 'gems is not fresh.'
        exit 1
      end
    end
  end
end
