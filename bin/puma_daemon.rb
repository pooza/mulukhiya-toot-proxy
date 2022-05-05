#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.expand_path('..', __dir__), 'app/lib'))
ENV['RAKE'] = nil

require 'mulukhiya'
module Mulukhiya
  exit 1 if PumaDaemon.disable?
  PumaDaemon.spawn!
end

