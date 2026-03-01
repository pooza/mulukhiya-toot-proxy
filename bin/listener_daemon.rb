#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.expand_path('..', __dir__), 'app/lib'))
ENV['RAKE'] = nil

require 'mulukhiya'
module Mulukhiya
  if ListenerDaemon.disable?
    warn "#{ListenerDaemon.name}: disabled, skipping"
    exit 0
  end
  ListenerDaemon.spawn!
end
