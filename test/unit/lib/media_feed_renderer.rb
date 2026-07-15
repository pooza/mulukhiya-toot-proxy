module Mulukhiya
  class MediaFeedRendererTest < TestCase
    def disable?
      return true unless Environment.dbms_class&.config?
      return true unless controller_class.feed?
      return super
    end

    def setup
      return if disable?
      @renderer = MediaFeedRenderer.new
    end

    def test_to_s
      r = @renderer.to_s

      assert_equal('<?xml version="1.0" encoding="UTF-8"?>', r.each_line.to_a.first.chomp)
      # <item> は media が seed されている時のみ現れる（to_s は attachment_class.feed から描画）。
      # harness 等 media 未 seed の環境では precondition 明示 omit。seed 追加は chubo2#64。
      # feed はブロック無しだと Enumerator を返すため none? で実データの有無を判定する。
      omit('テスト用メディア未 seed（chubo2#64）') if attachment_class.feed.none?

      assert_includes(r, '<item>')
    end

    def test_uri
      assert_kind_of(Ginseng::URI, MediaFeedRenderer.uri)
      assert_predicate(MediaFeedRenderer.uri, :absolute?)

      # http.get は mulukhiya の HTTP エンドポイント（/mulukhiya/feed/media）に到達する。
      # harness はこれを提供せず 404 を返すため、endpoint 未提供（404）の環境でのみ omit する。
      # 404 以外の異常はそのまま失敗させ product の回帰検出力を保つ。provisioning は chubo2#63。
      begin
        response = http.get(MediaFeedRenderer.uri)
      rescue Ginseng::GatewayError => e
        raise unless e.message.include?('404')

        omit("mulukhiya HTTP エンドポイント未提供（#{e.message}・chubo2#63）")
      end

      assert_kind_of(HTTParty::Response, response)
    end
  end
end
