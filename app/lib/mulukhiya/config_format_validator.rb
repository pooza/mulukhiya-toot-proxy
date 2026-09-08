module Mulukhiya
  # JSON Schema の `format: regex` を**実際に**検証する (#4597)。
  #
  # ⚠⚠ **json-schema には `regex` の検証実装がそもそも無い。**`format: regex` と
  # 書いてあっても `[unclosed` も `(?<broken` も素通しする。⚠ `validate_formats: true`
  # を渡しても変わらない（`date-time` などは効くが `regex` / `hostname` / `email` は
  # 実装が無い）。**フラグの問題ではない。**
  #
  # 🔴 **いちばん効くのは `/sentry/scrub_patterns`。**`Mulukhiya.setup_sentry` は
  # `before_send` の中で毎回 `Regexp.new` を呼ぶので、**壊れたパターンは
  # `config:lint` を通り、Sentry へイベントを送ろうとした瞬間に初めて
  # `RegexpError` になる**。⚠⚠ sentry-ruby の `Client#send_event` は
  # `before_send.call` を rescue していないので、**例外を集める仕組みが例外で止まる**。
  # ⚠ 設定した本人は「スクラブしているつもり」なので、無音のまま漏れる。
  #
  # ⚠ **場所を列挙しない。**schema を歩いて `format: regex` の付いた値を拾うので、
  # schema に足した瞬間から検証対象になる。列挙すると必ずずれる。
  class ConfigFormatValidator
    include Package

    # 実際にコンパイルして確かめる format。⚠ `hostname` / `email` は
    # `pattern` で表現できるので schema 側で書き換えた。ここに残すのは
    # **JSON Schema の語彙で表現できない**ものだけ。
    COMPILED_FORMATS = ['regex'].freeze

    def initialize(schema = nil, values = nil)
      @schema = schema || Config.instance.schema
      @values = values || Config.instance.merged_raw
    end

    def errors
      @errors = []
      walk(@schema, @values, '')
      return @errors
    end

    private

    def walk(schema, value, path)
      return unless schema.is_a?(Hash)
      verify(schema, value, path)
      walk_properties(schema, value, path)
      walk_items(schema, value, path)
    end

    def walk_properties(schema, value, path)
      properties = schema['properties'] || schema[:properties]
      return unless properties.is_a?(Hash) && value.is_a?(Hash)
      properties.each do |key, child|
        next unless value.key?(key.to_s)
        walk(child, value[key.to_s], "#{path}/#{key}")
      end
    end

    def walk_items(schema, value, path)
      items = schema['items'] || schema[:items]
      return unless items.is_a?(Hash) && value.is_a?(Array)
      value.each_with_index {|v, i| walk(items, v, "#{path}[#{i}]")}
    end

    def verify(schema, value, path)
      format = schema['format'] || schema[:format]
      return unless COMPILED_FORMATS.include?(format)
      return unless value.is_a?(String)
      Regexp.new(value)
    rescue RegexpError => e
      # ⚠ **値そのものは出す。**壊れた正規表現は秘密情報ではないし、
      # どこが壊れているか分からないと直せない。
      @errors.push("The property '##{path}' is not a valid regular expression: #{e.message}")
    end
  end
end
