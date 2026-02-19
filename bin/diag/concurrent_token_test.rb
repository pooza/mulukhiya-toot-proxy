#!/usr/bin/env ruby

# Concurrent token isolation test for rack 3.2 (Issue #4055)
#
# Verifies that Puma's multi-threaded request handling does not
# cause token contamination between concurrent requests.
#
# Usage:
#   ruby bin/diag/concurrent_token_test.rb \
#     --tokens TOKEN_A,TOKEN_B \
#     --concurrency 10 --rounds 50 --type mastodon

require 'net/http'
require 'json'
require 'optparse'

options = {
  host: 'localhost',
  port: 3008,
  concurrency: 10,
  rounds: 50,
  type: 'mastodon',
}

OptionParser.new do |opts|
  opts.banner = 'Usage: concurrent_token_test.rb [options]'
  opts.on('--host HOST', 'Target host (default: localhost)') {|v| options[:host] = v}
  opts.on('--port PORT', Integer, 'Target port (default: 3008)') {|v| options[:port] = v}
  opts.on('--tokens TOKENS', 'Comma-separated OAuth tokens (2+)') {|v| options[:tokens] = v.split(',')}
  opts.on('--concurrency N', Integer, 'Concurrent threads (default: 10)') {|v| options[:concurrency] = v}
  opts.on('--rounds N', Integer, 'Number of rounds (default: 50)') {|v| options[:rounds] = v}
  opts.on('--type TYPE', 'mastodon or misskey (default: mastodon)') {|v| options[:type] = v}
end.parse!

unless options[:tokens]&.length&.>=(2)
  warn 'Error: --tokens requires 2 or more comma-separated tokens'
  exit 2
end

path = case options[:type]
       when 'mastodon' then '/api/v1/mulukhiya/diag'
       when 'misskey' then '/api/mulukhiya/diag'
       else
         warn "Error: --type must be 'mastodon' or 'misskey'"
         exit 2
       end

tokens = options[:tokens]
total = 0
failures = []

puts '=== Concurrent Token Isolation Test ==='
puts "Host: #{options[:host]}:#{options[:port]}"
puts "Type: #{options[:type]}"
puts "Path: #{path}"
puts "Tokens: #{tokens.length} / Concurrency: #{options[:concurrency]} / Rounds: #{options[:rounds]}"
puts

options[:rounds].times do |round|
  threads = []
  results = Queue.new

  options[:concurrency].times do |i|
    t = tokens[i % tokens.length]
    threads << Thread.new(t) do |send_token|
      uri = URI("http://#{options[:host]}:#{options[:port]}#{path}")
      req = Net::HTTP::Get.new(uri)
      req['Authorization'] = "Bearer #{send_token}"
      res = Net::HTTP.start(uri.hostname, uri.port) {|http| http.request(req)}
      results << {
        sent_prefix: send_token[0, 8],
        status: res.code.to_i,
        body: (JSON.parse(res.body) rescue nil),
      }
    rescue => e
      results << {sent_prefix: send_token[0, 8], error: e.message}
    end
  end

  threads.each(&:join)
  round_failures = []

  until results.empty?
    r = results.pop
    total += 1

    if r[:error]
      round_failures << "ERROR: #{r[:error]}"
      next
    end

    if r[:status] != 200
      round_failures << "HTTP #{r[:status]}: sent=#{r[:sent_prefix]}"
      next
    end

    body = r[:body]
    unless body
      round_failures << "PARSE_ERROR: sent=#{r[:sent_prefix]}"
      next
    end

    unless body['match'] == true && body['token_prefix'] == r[:sent_prefix]
      round_failures << [
        "MISMATCH: sent=#{r[:sent_prefix]}",
        "received=#{body['token_prefix']}",
        "sns=#{body['sns_token_prefix']}",
        "match=#{body['match']}",
        "thread=#{body['thread_id']}",
      ].join(' ')
    end
  end

  failures.concat(round_failures)
  ok = options[:concurrency] - round_failures.length
  label = format('Round %*d/%d', options[:rounds].to_s.length, round + 1, options[:rounds])

  if round_failures.empty?
    puts "#{label}: #{ok}/#{options[:concurrency]} OK"
  else
    puts "#{label}: #{ok}/#{options[:concurrency]} OK, #{round_failures.length} FAILED"
    round_failures.each {|f| puts "  #{f}"}
  end
end

puts
puts '=== Results ==='
passed = total - failures.length
rate = total.positive? ? (passed.to_f / total * 100) : 0
puts "Total: #{total} / Passed: #{passed} / Failed: #{failures.length}"
puts format('Success rate: %.1f%%', rate)
puts

if failures.empty?
  puts 'PASS'
  exit 0
else
  puts 'FAIL - Token contamination detected!'
  exit 1
end
