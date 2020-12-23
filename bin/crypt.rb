#!/usr/bin/env ruby
dir = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(dir, 'app/lib'))
ENV['BUNDLE_GEMFILE'] = File.join(dir, 'Gemfile')

require 'mulukhiya'

puts Mulukhiya::Package.full_name
puts 'パスワード暗号化ユーティリティ'
puts ''

unless password = ARGV.first
  warn '文字列を指定してください。'
  exit 1
end

puts "source:  #{password}"
puts "crypted: #{Mulukhiya::Crypt.new.encrypt(password)}"
