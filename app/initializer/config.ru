dir = File.expand_path('../..', __dir__)
$LOAD_PATH.unshift(File.join(dir, 'app/lib'))
ENV['BUNDLE_GEMFILE'] ||= File.join(dir, 'Gemfile')

require 'bundler/setup'
require 'sidekiq/web'
require 'sidekiq-scheduler/web'
require 'mulukhiya_toot_proxy'

config = MulukhiyaTootProxy::Config.instance
if config['/sidekiq/auth/user'].present? && config['/sidekiq/auth/password'].present?
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    MulukhiyaTootProxy::Environment.auth(username, password)
  end
end

run Rack::URLMap.new(
  '/' => MulukhiyaTootProxy::Server,
  '/mulukhiya/sidekiq' => Sidekiq::Web,
)
