#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.expand_path('..', __dir__), 'app/lib'))
ENV['RAKE'] = nil

require 'mulukhiya'
module Mulukhiya
  if SidekiqDaemon.disable?
    warn "#{SidekiqDaemon.name}: disabled, skipping"
    exit 0
  end
  SidekiqDaemon.spawn!
end
