#!/usr/bin/env ruby

dir = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(dir, 'lib'))
ENV['BUNDLE_GEMFILE'] ||= File.join(dir, 'Gemfile')
ENV['SSL_CERT_FILE'] ||= File.join(dir, 'cert/cacert.pem')

require 'bundler/setup'
require 'mulukhiya_toot_proxy'

MulukhiyaTootProxy::ThinDaemon.spawn!({
  working_dir: MulukhiyaTootProxy::Environment.dir,
  pid_file: 'tmp/pids/thin_daemon.pid',
  log_file: 'log/thin.log',
  sync_log: true,
  singleton: true,
})
