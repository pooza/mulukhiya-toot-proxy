ROOT_DIR = File.expand_path(__dir__)
$LOAD_PATH.push(File.join(ROOT_DIR, 'lib'))
$LOAD_PATH.push(File.join(ROOT_DIR, 'app'))
ENV['BUNDLE_GEMFILE'] ||= File.join(ROOT_DIR, 'Gemfile')
ENV['SSL_CERT_FILE'] ||= File.join(ROOT_DIR, 'cert/cacert.pem')

require 'bundler/setup'
require 'mulukhiya_toot_proxy'

desc 'test'
task :test do
  require 'test/unit'
  Dir.glob(File.join(ROOT_DIR, 'test/*')).each do |t|
    require t
  end
end

[:start, :stop, :restart].each do |action|
  desc "alias of server:#{action}"
  task action => ["server:#{action}"]
end

namespace :server do
  [:start, :stop, :restart].each do |action|
    desc "#{action} server"
    task action do
      sh "thin --config config/thin.yaml #{action}"
    end
  end
end

namespace :sidekiq do
  desc 'start sidekiq'
  task :start do
    sh 'sidekiq -C config/sidekiq.yaml -r ./sidekiq.rb'
  end

  desc 'stop sidekiq'
  task :stop do
    sh 'kill `cat tmp/pids/sidekiq.pid`'
  end
end
