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

  desc 'check cert'
  task :check do
    if `git status`.include?('cacert.pem')
      STDERR.puts 'cert is not fresh.'
      exit 1
    end
  end
end

namespace :bundle do
  desc 'update gems'
  task :update do
    sh 'bundle update'
  end

  desc 'check gems'
  task :check do
    if `git status`.include?('Gemfile.lock')
      STDERR.puts 'gems is not fresh.'
      exit 1
    end
  end
end

namespace :repos do
  desc 'update cert/gems'
  task update: ['cert:update', 'bundle:update']

  desc 'check cert/gems'
  task check: ['cert:check', 'bundle:check']
end

namespaces = [:thin, :sidekiq]
apps = []

namespaces.each do |ns|
  app = "#{ns.to_s.camelize}Daemon"
  apps.push(app)

  namespace ns do
    [:start, :stop].each do |action|
      desc "#{action} #{app}"
      task action do
        sh "#{File.join(environment.dir, 'bin', "#{ns}_daemon.rb")} #{action}"
      rescue => e
        STDERR.puts "#{e.class} #{ns}:#{action} #{e.message}"
      end
    end

    desc "restart #{app}"
    task restart: [:stop, :start]
  end
end

[:start, :stop, :restart].each do |action|
  desc "#{action} #{apps.join('/')}"
  task action => namespaces.map{|ns| "#{ns}:#{action}"}
end
