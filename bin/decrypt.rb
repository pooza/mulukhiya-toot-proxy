#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.expand_path('..', __dir__), 'app/lib'))

require 'mulukhiya'
module Mulukhiya
  warn Package.full_name
  warn File.basename(__FILE__)
  warn ''
  raise '/crypt/password が未設定です。' unless Crypt.config?
  password = ARGV.getopts('', 'text:')['text'] || ARGV.first
  raise '文字列を指定してください。' unless password.present?
  puts password.decrypt
rescue => e
  warn e.message
  exit 1
end
