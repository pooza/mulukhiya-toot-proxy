#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.expand_path('..', __dir__), 'app/lib'))

require 'mulukhiya'
require 'optparse'
module Mulukhiya
  warn Package.full_name
  warn File.basename(__FILE__)
  warn ''
  options = {}
  OptionParser.new do |opt|
    opt.on('--cases=CASES', 'テストケース') {|v| options[:cases] = v}
  end.parse!
  TestCase.load(options[:cases] || ARGV.first)
rescue => e
  warn e.message
  exit 1
end
