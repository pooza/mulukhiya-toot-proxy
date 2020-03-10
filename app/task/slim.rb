namespace :slim do
  desc 'lint all Slim templates'
  task :lint do
    sh "bundle exec slim-lint #{File.join(Mulukhiya::Environment.dir, 'views/**/*.slim')}"
  end
end
