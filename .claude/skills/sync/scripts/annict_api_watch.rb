# Annict（annict/annict）の API 周りに動きがあったかを見る (#3157 / #4801)。
# 使い方: ruby .claude/skills/sync/scripts/annict_api_watch.rb
# 読み方は SKILL.md の §6-4。
require 'json'

def api(path)
  return JSON.parse(`gh api '#{path}'`)
rescue JSON::ParserError
  return []
end

puts 'rails/app/graphql の直近のコミット:'
api('repos/annict/annict/commits?path=rails/app/graphql&per_page=3').each do |c|
  puts "  #{c.dig('commit', 'author', 'date')[0,
    10]} #{c.dig('commit', 'message').lines.first.strip}"
end

puts 'Go 側の API らしきディレクトリ:'
found = ['go/internal', 'go/internal/handler'].flat_map do |dir|
  api("repos/annict/annict/contents/#{dir}").filter_map do |entry|
    "#{dir}/#{entry['name']}" if entry['type'] == 'dir' && entry['name'].match?(/graphql|api/i)
  end
end
puts found.empty? ? '  なし' : found.map {|v| "  #{v}"}.join("\n")
