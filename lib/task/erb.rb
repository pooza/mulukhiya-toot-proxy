namespace :erb do
  desc 'lint ERB'
  task :check do
    Dir.chdir(File.join(MulukhiyaTootProxy::Environment.dir, 'views'))
    sh 'rails-erb-lint check -v'
  end
end
