#!/usr/bin/env ruby
dir = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(dir, 'app/lib'))
ENV['BUNDLE_GEMFILE'] = File.join(dir, 'Gemfile')

require 'mulukhiya'
module Mulukhiya
  warn Package.full_name
  warn '復号化ユーティリティ'
  warn ''

  password = ARGV.first
  raise '文字列を指定してください。' unless password.present?
  puts password.decrypt
rescue => e
  warn e.message
  exit 1
end
