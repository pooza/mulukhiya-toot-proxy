dir = File.expand_path(__dir__)
$LOAD_PATH.unshift(File.join(dir, 'lib'))
ENV['BUNDLE_GEMFILE'] ||= File.join(dir, 'Gemfile')
ENV['SSL_CERT_FILE'] ||= File.join(dir, 'cert/cacert.pem')

require 'bundler/setup'
require 'mulukhiya_toot_proxy'

desc 'test'
task :test do
  require 'test/unit'
  Dir.glob(File.join(MulukhiyaTootProxy::Environment.dir, 'test/*')).each do |t|
    require t
  end
end

namespace :cert do
  desc 'update cert'
  task :update do
    require 'httparty'
    File.write(
      File.join(MulukhiyaTootProxy::Environment.dir, 'cert/cacert.pem'),
      HTTParty.get('https://curl.haxx.se/ca/cacert.pem'),
    )
  end
end

[:start, :stop, :restart].each do |action|
  desc "#{action} API server / Sidekiq daemon"
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
  [:start, :stop].each do |action|
    desc "#{action} Sidekiq daemon"
    task action do
      sh "#{File.join(MulukhiyaTootProxy::Environment.dir, 'bin/sidekiq_daemon.rb')} #{action}"
    end
  end

  desc 'restart Sidekiq daemon'
  task restart: [:stop, :start]
end
