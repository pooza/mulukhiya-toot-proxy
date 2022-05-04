#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.expand_path('..', __dir__), 'app/lib'))
ENV['RAKE'] = nil

require 'mulukhiya'
exit 1 if  Mulukhiya::ListenerDaemon.disable?
Mulukhiya::Environment.listener_class.start
