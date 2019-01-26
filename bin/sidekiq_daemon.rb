#!/usr/bin/env ruby

dir = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(dir, 'lib'))
ENV['BUNDLE_GEMFILE'] ||= File.join(dir, 'Gemfile')
ENV['SSL_CERT_FILE'] ||= File.join(dir, 'cert/cacert.pem')

require 'bundler/setup'
require 'mulukhiya_toot_proxy'

MulukhiyaTootProxy::SidekiqDaemon.spawn!({
  working_dir: MulukhiyaTootProxy::Environment.dir,
  pid_file: 'tmp/pids/sidekiq_daemon.pid',
  log_file: 'log/sidekiq.log',
  sync_log: true,
  singleton: true,
})
