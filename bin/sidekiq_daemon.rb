#!/usr/bin/env ruby
dir = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(dir, 'app/lib'))
ENV['BUNDLE_GEMFILE'] = File.join(dir, 'Gemfile')
ENV['RAKE'] = nil

Dir.chdir(dir)
require 'mulukhiya'
module Mulukhiya
  ENV['RACK_ENV'] ||= Environment.type
  SidekiqDaemon.spawn!
end
