module Mulukhiya
  extend Rake::DSL

  namespace :erb do
    desc 'lint all ERB templates'
    task :lint do
      Dir.chdir(File.join(Environment.dir, 'views'))
      sh 'bundle exec rails-erb-lint check -v'
    end
  end
end
