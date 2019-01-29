dir = File.expand_path(__dir__)
$LOAD_PATH.unshift(File.join(dir, 'lib'))
ENV['BUNDLE_GEMFILE'] ||= File.join(dir, 'Gemfile')
ENV['SSL_CERT_FILE'] ||= File.join(dir, 'cert/cacert.pem')

require 'bundler/setup'
require 'mulukhiya_toot_proxy'

environment = MulukhiyaTootProxy::Environment

desc 'test'
task :test do
  require 'test/unit'
  Dir.glob(File.join(environment.dir, 'test/*')).each do |t|
    require t
  end
end

namespace :cert do
  desc 'update cert'
  task :update do
    require 'httparty'
    File.write(
      File.join(environment.dir, 'cert/cacert.pem'),
      HTTParty.get('https://curl.haxx.se/ca/cacert.pem'),
    )
  end
end

[:start, :stop, :restart].each do |action|
  desc "#{action} ThinDaemon / SidekiqDaemon"
  task action => ["thin:#{action}", "sidekiq:#{action}"]
end

[:thin, :sidekiq].each do |ns|
  app_name = "#{ns.to_s.camelize}Daemon"

  namespace ns do
    [:start, :stop].each do |action|
      desc "#{action} #{app_name}"
      task action do
        sh "#{File.join(environment.dir, 'bin/', "#{ns}_daemon.rb")} #{action}"
      rescue => e
        STDERR.puts "#{e.class} #{ns}:#{action} #{e.message}"
      end
    end

    desc "restart #{app_name}"
    task restart: [:stop, :start]
  end
end
