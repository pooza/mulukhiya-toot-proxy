module Mulukhiya
  extend Rake::DSL

  namespace :rubocop do
    desc 'rubocop'
    task :lint do
      Dir.chdir(Environment.dir)
      sh 'rubocop'
    end
  end
end
