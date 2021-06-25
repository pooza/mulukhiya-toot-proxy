#!/usr/bin/env ruby
dir = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(dir, 'app/lib'))
ENV['BUNDLE_GEMFILE'] = File.join(dir, 'Gemfile')

require 'mulukhiya'
module Mulukhiya
  puts Package.full_name
  puts 'テストローダー'
  puts '> test.rb'
  puts '> test.rb --cases account,tagging_handler'
  puts ''
  TestCase.load(ARGV.getopts('', 'cases:')['cases'])
rescue => e
  warn e.message
  exit 1
end
