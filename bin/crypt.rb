#!/usr/bin/env ruby
dir = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(dir, 'app/lib'))
ENV['BUNDLE_GEMFILE'] = File.join(dir, 'Gemfile')

require 'mulukhiya'
ENV['RACK_ENV'] ||= Mulukhiya::Environment.type

unless password = ARGV.first
  warn '文字列を指定してください。'
  exit 1
end

puts "source: #{ARGV.first}"
puts "dest:   #{Mulukhiya::Crypt.new.encrypt(password)}"
