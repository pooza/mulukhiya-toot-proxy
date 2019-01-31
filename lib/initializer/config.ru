dir = File.expand_path('../..', __dir__)
$LOAD_PATH.unshift(File.join(dir, 'lib'))
ENV['BUNDLE_GEMFILE'] ||= File.join(dir, 'Gemfile')
ENV['SSL_CERT_FILE'] ||= File.join(dir, 'cert/cacert.pem')

require 'bundler/setup'
require 'sidekiq/web'
require 'mulukhiya_toot_proxy'

run Rack::URLMap.new({
  '/' => MulukhiyaTootProxy::Server,
  '/mulukhiya/sidekiq' => Sidekiq::Web,
})
