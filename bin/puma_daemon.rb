#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.expand_path('..', __dir__), 'app/lib'))
ENV['RAKE'] = nil

require 'mulukhiya'
module Mulukhiya
  if PumaDaemon.disable?
    warn "#{PumaDaemon.name}: disabled, skipping"
    exit 0
  end
  PumaDaemon.spawn!(singleton: true)
end
