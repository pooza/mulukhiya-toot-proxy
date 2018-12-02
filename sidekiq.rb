ROOT_DIR = File.expand_path(__dir__)
$LOAD_PATH.push(File.join(ROOT_DIR, 'lib'))
$LOAD_PATH.push(File.join(ROOT_DIR, 'app'))
ENV['BUNDLE_GEMFILE'] ||= File.join(ROOT_DIR, 'Gemfile')
ENV['SSL_CERT_FILE'] ||= File.join(ROOT_DIR, 'cert/cacert.pem')

require 'bundler/setup'
require 'mulukhiya_toot_proxy'
require 'sidekiq'

Sidekiq.configure_server do |config|
  config.redis = {url: MulukhiyaTootProxy::Config.instance['/sidekiq/redis/dsn']}
end

Dir.glob(File.join(ROOT_DIR, 'app/worker/*')).each do |worker|
  require worker
end
