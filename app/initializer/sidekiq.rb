dir = File.expand_path('../..', __dir__)
$LOAD_PATH.unshift(File.join(dir, 'app/lib'))
ENV['BUNDLE_GEMFILE'] ||= File.join(dir, 'Gemfile')

MulukhiyaTootProxy::Postgres.connect

require 'bundler/setup'
require 'mulukhiya_toot_proxy'
