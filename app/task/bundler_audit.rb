module Mulukhiya
  extend Rake::DSL

  namespace :bundler_audit do
    desc 'bundler-audit'
    task :check do
      Dir.chdir(Environment.dir)
      sh 'bundler-audit check --update'
    end
  end
end
