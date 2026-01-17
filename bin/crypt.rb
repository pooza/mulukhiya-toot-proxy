#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.expand_path('..', __dir__), 'app/lib'))

require 'mulukhiya'
require 'optparse'
module Mulukhiya
  warn Package.full_name
  warn File.basename(__FILE__)
  warn ''
  raise '/crypt/password が未設定です。' unless Crypt.config?
  options = {}
  OptionParser.new do |opt|
    opt.on('--text=TEXT', '暗号化する文字列') {|v| options[:text] = v}
  end.parse!
  password = options[:text] || ARGV.first
  raise '文字列を指定してください。' unless password.present?
  puts password.encrypt
rescue => e
  warn e.message
  exit 1
end
