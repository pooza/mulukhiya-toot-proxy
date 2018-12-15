ROOT_DIR = File.expand_path(__dir__)
$LOAD_PATH.push(File.join(ROOT_DIR, 'lib'))
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

namespace :cert do
  desc 'update cert'
  task :update do
    require 'httparty'
    File.write(
      File.join(ROOT_DIR, 'cert/cacert.pem'),
      HTTParty.get('https://curl.haxx.se/ca/cacert.pem'),
    )
  end
end

[:start, :stop, :restart].each do |action|
  desc "#{action} API server / Sidekiq"
  task action => ["server:#{action}", "sidekiq:#{action}"]
end

namespace :server do
  [:start, :stop, :restart].each do |action|
    desc "#{action} API server"
    task action do
      sh "thin --config config/thin.yaml #{action}"
    end
  end
end

namespace :sidekiq do
  desc 'start Sidekiq'
  task :start do
    sh 'sidekiq --daemon --config config/sidekiq.yaml --require ./sidekiq.rb'
  end

  desc 'stop Sidekiq'
  task :stop do
    sh 'kill `cat tmp/pids/sidekiq.pid`' rescue nil
  end

  desc 'restart Sidekiq'
  task restart: [:stop, :start]
end
