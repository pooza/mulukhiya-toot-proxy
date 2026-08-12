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
      # ⚠ ガードは #fetch の描画条件と同じ順に並べる。以前は feed の中身だけを見ており、
      # media_catalog が OFF のときも「seed はあるのに <item> が無い」で落ちていた (#4516)。
      #
      # 1. media_catalog が無効なら #fetch は entries を空にして即 return する。
      #    5.23.0 (#4343) から既定 OFF なので、この状態で <item> が無いのは仕様どおり。
      omit('media_catalog が無効（5.23.0 から既定 OFF・#4343）') unless controller_class.media_catalog?

      # 2. <item> は media が seed されている時のみ現れる。harness は media を seed
      #    しないため harness 駆動時のみ omit する。seed 追加は chubo2#64。
      #    非 harness（本番等）で media が無いのは実退行なので下の assert で落とす。
      #    feed はブロック無しだと Enumerator を返すため none? で実データの有無を判定する。
      omit('テスト用メディア未 seed（chubo2#64）') if harness? && attachment_class.feed.none?

      assert_includes(r, '<item>')
    end

    def test_uri
      assert_kind_of(Ginseng::URI, MediaFeedRenderer.uri)
      assert_predicate(MediaFeedRenderer.uri, :absolute?)

      # http.get は mulukhiya の HTTP エンドポイント（/mulukhiya/feed/media）に到達する。
      # harness はこれを提供せず 404 を返すため、harness 駆動時の 404 でのみ omit する。
      # 非 harness の 404（＝本番でエンドポイント消失）や 404 以外の異常はそのまま失敗させ
      # product の回帰検出力を保つ。provisioning は chubo2#63。
      begin
        response = http.get(MediaFeedRenderer.uri)
      rescue Ginseng::GatewayError => e
        raise unless harness? && e.message.include?('404')

        omit("mulukhiya HTTP エンドポイント未提供（#{e.message}・chubo2#63）")
      end

      assert_kind_of(HTTParty::Response, response)
    end
  end
end
