module Mulukhiya
  class ClippingWorker < Worker
    sidekiq_options retry: 3

    def federate?
      return true if Environment.test?
      return worker_config(:federate)
    end

    def perform(params)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def create_body(params)
      params.deep_symbolize_keys!
      uri = create_status_uri(params[:uri])
      raise Ginseng::RequestError, "Invalid URL '#{params[:uri]}'" unless uri&.valid?
      return uri.to_md if federate?
      return uri.to_md if uri.public?
      return uri.to_md if uri.local?
      return uri.to_s
    rescue => e
      # 内側が既に GatewayError なら包み直さない（上流のレスポンスが落ちる、#4480）。
      #
      # ⚠ ここが効くのは create_status_uri が投げた経路（uri が nil）だけで、
      # uri.to_md 由来の GatewayError は下の生 URL フォールバックへ倒れる。
      # **非対称なのは意図的**（Codex #4527 P2 を却下）。戻り値は投稿本文なので、
      # 上流が落ちたら「リンクだけの投稿」を残すほうがよく、再 raise すると
      # retry: 3 を使い切って dead 送り＝投稿そのものが消える。#4480 の透過は
      # 返す相手（API クライアント）がいるリクエスト層の要求で、ワーカーには
      # 及ぼさない。上流のレスポンスは下の e.log(uri:) で記録される。
      raise e if e.is_a?(Ginseng::GatewayError) && uri.nil?
      raise Ginseng::GatewayError, e.message, e.backtrace unless uri
      e.log(uri: uri.to_s)
      return uri.to_s
    end
  end
end
