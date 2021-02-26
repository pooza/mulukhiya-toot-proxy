namespace :erb do
  desc 'lint all ERB templates'
  task :lint do
    Dir.chdir(File.join(Mulukhiya::Environment.dir, 'views'))
    sh 'bundle exec rails-erb-lint check -v'
  end
end
