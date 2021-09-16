module Mulukhiya
  extend Rake::DSL

  namespace :slim do
    desc 'lint all Slim templates'
    task :lint do
      sh "bundle exec slim-lint #{::File.join(Environment.dir, 'views/**/*.slim')}"
    end
  end
end
