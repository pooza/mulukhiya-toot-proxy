module Mulukhiya
  # 上流のエラー応答（`Ginseng::GatewayError#response`）から読むもの。
  #
  # ⚠ Controller の行数に収めるための切り出し（`LogScrubber` と同じ扱い）。
  #
  # 待ち時間ヘッダの中継 (#4775):
  # 🔴 **Mastodon は 429 に `Retry-After` を付けず、`X-RateLimit-Reset`（ISO 8601）だけを返す。**
  # 中継しないと、経由したクライアントには「429 だが、いつ解けるか分からない」と見え、
  # 固定の間隔で叩き直して規制を長引かせる（pooza/makoto2 の MAKOTO で踏む形）。
  module UpstreamErrorMethods
    # ⚠ **丸投げはしない。**待ち時間の判断に要るものだけを許可リストに置く
    # （`Set-Cookie` や `Content-Length` など、上流の応答の都合を持ち込まない）。
    RELAYED_UPSTREAM_HEADERS = [
      'Retry-After', 'X-RateLimit-Limit', 'X-RateLimit-Remaining', 'X-RateLimit-Reset'
    ].freeze

    # 上流の `{"error": {"code": "..."}}` から code を取る。取れなければ nil。
    #
    # ⚠ Mastodon の包絡は `{"error": "Validation failed: ..."}` で error が
    # **文字列**。Hash 前提で dig すると TypeError になる。上流の形を決め打ち
    # できないので、各段で型を確かめる。
    def upstream_error_code(error)
      body = error.source_body
      return nil unless body.is_a?(Hash)
      envelope = body['error']
      return nil unless envelope.is_a?(Hash)
      return envelope['code']
    end

    private

    # 上流の応答ヘッダのうち、待ち時間の判断に要るものを付ける。
    #
    # ⚠ 呼ぶのは**上流のステータスを透過するときだけ**（`WrappedGatewayError` の
    # 502 には付けない）。他人のサーバーや内部読みの待ち時間を、モロヘイヤの
    # 上流の規制として読ませてはいけない (#4537)。
    def relay_upstream_headers(error)
      values = RELAYED_UPSTREAM_HEADERS.to_h do |name|
        [name, upstream_header(error.response, name)]
      end.compact
      headers(values) unless values.empty?
    end

    # 上流の応答からヘッダを 1 つ取り出す。無ければ nil。
    #
    # ⚠⚠ **応答の型が 2 つある**（pooza/ginseng-core#549 と同じ事情）。`HTTParty::Response` は
    # `headers` で読み、`Net::HTTPResponse` は `response[name]` で読む。⚠ **`HTTParty::Response#[]`
    # は body（パース結果）を引く**ので、`headers` を先に見る。
    # ⚠ 改行を含む値は捨てる（応答ヘッダの分割になる）。
    def upstream_header(response, name)
      value = if response.respond_to?(:headers)
        response.headers[name]
      elsif response.is_a?(Net::HTTPResponse)
        response[name]
      end
      value = value.to_s.strip
      return nil if value.empty? || value.match?(/[\r\n]/)
      return value
    end
  end
end
