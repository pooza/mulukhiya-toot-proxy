# Gemfile で固定した ginseng-* の版と、各リポジトリの最新タグを突き合わせる。
# 使い方（リポジトリのルートで）: ruby .claude/skills/sync/scripts/ginseng_pin_drift.rb
pattern = /gem .(ginseng-[\w-]+).,\s+github: \S+,\s+(tag|ref): .(\w[\w.]*)./
File.read('Gemfile').scan(pattern) do |name, kind, pin|
  tags = `git ls-remote --tags --sort=-v:refname https://github.com/pooza/#{name}.git "v*"`
  latest = tags[%r{refs/tags/(v[\d.]+)$}, 1]
  tagged = %r{^#{pin}\trefs/tags/#{Regexp.escape(latest)}(\^\{\})?$}
  ok = kind == 'tag' ? pin == latest : tags.match?(tagged)
  puts "#{name}\t#{ok ? "最新 #{latest}" : "ずれ #{pin[0, 12]} -> #{latest}"}"
end
