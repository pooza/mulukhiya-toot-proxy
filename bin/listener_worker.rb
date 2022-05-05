#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.expand_path('..', __dir__), 'app/lib'))
ENV['RAKE'] = nil

require 'mulukhiya'
module Mulukhiya
  exit 1 if ListenerDaemon.disable?
  Environment.listener_class.start
end
