module Mulukhiya
  class MastodonController < Controller
    include ControllerMethods

    # ALT 編集 (PUT /api/:version/statuses/:id) で Sentry alert を抑止する
    # 上流ステータス (#4542)。
    #
    # 404 は「編集対象が存在しない・削除済み・リモートの投稿」で出る
    # **クライアントエラー**。capsicum の操作次第で常時発生しうるので、
    # alert に乗せるとノイズが積み上がるだけで運用判断に使えない。
    #
    # ⚠ 抑止するのは Sentry だけで syslog には残る (controller.rb の
    # handle_gateway_error)。「上流が /source を廃止して全滅」のような事故は
    # 頻度・偏りで追える。
    STATUS_UPDATE_SILENT_STATUSES = [401, 404].freeze

    # PUT /api/:version/statuses/:id が受け付ける X-Mulukhiya-Purpose。
    # nil / '' は nginx を経由しない直接アクセス（#4474 の map が外部からの
    # Purpose 無し PUT を 405 で弾くため、実質モロヘイヤ自身の転送のみ）。
    STATUS_UPDATE_PURPOSES = [nil, '', 'media_update', 'tag'].freeze

    post '/api/:version/statuses' do
      verify_token_integrity!
      tags = TootParser.new(params[:status]).tags
      Event.new(:pre_toot, {reporter:, sns:}).dispatch(params)
      # ⚠ **クライアントの Idempotency-Key を上流へ渡す (#4598)。**渡さないと、
      # 応答だけ失われたときの再送が二重投稿になる。ハンドラで本文が書き換わって
      # いても、キーが一致すれば上流は既存の投稿を返すので問題にならない。
      reporter.response = sns.toot(params, {headers: forwarded_headers})
      verify_account_integrity!(reporter.response)
      Event.new(:post_toot, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.message['tags']&.select! {|v| tags.member?(v['name'])}
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_gateway_error(e)
      return @renderer.to_s
    end

    post '/api/:version/media' do
      verify_token_integrity!
      Event.new(:pre_upload, {reporter:, sns:}).dispatch(params)
      reporter.response = sns.upload(params.dig(:file, :tempfile), {
        version: api_version,
        filename: params[:name],
        description: params[:description],
      }.compact)
      Event.new(:post_upload, {reporter:, sns:}).dispatch(params)
      @renderer.message = JSON.parse(reporter.response.body)
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_upload_gateway_error(e)
      return @renderer.to_s
    end

    put '/api/:version/media/:id' do
      verify_token_integrity!
      Event.new(:pre_thumbnail, {reporter:, sns:}).dispatch(params) if params[:thumbnail]
      reporter.response = sns.update_media(params[:id], params)
      Event.new(:post_thumbnail, {reporter:, sns:}).dispatch(params) if params[:thumbnail]
      @renderer.message = JSON.parse(reporter.response.body)
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_upload_gateway_error(e)
      return @renderer.to_s
    end

    put '/api/:version/statuses/:id' do
      verify_token_integrity!
      purpose = request.env['HTTP_X_MULUKHIYA_PURPOSE']
      validate_status_update!(purpose, params)
      reporter.response = sns.update_status(
        params[:id],
        create_status_update_body(purpose, params),
        {headers: upstream_headers},
      )
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::ValidateError => e
      @renderer.message = {error: e.message}
      @renderer.status = 422
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_gateway_error(e, silent_statuses: STATUS_UPDATE_SILENT_STATUSES)
      return @renderer.to_s
    end

    post '/api/:version/statuses/:id/favourite' do
      verify_token_integrity!
      reporter.response = sns.fav(params[:id])
      verify_account_integrity!(reporter.response)
      Event.new(:post_fav, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_gateway_error(e)
      return @renderer.to_s
    end

    post '/api/:version/statuses/:id/reblog' do
      verify_token_integrity!
      reporter.response = sns.boost(params[:id])
      verify_account_integrity!(reporter.response)
      Event.new(:post_boost, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_gateway_error(e)
      return @renderer.to_s
    end

    post '/api/:version/statuses/:id/bookmark' do
      verify_token_integrity!
      reporter.response = sns.bookmark(params[:id])
      verify_account_integrity!(reporter.response)
      Event.new(:post_bookmark, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_gateway_error(e)
      return @renderer.to_s
    end

    get '/api/v1/mulukhiya/diag' do
      @renderer.message = token_echo_response
      return @renderer.to_s
    end

    # purpose ごとに必須パラメータが違う。
    #
    # ⚠ **`tag` に `media_attributes` を要求しない。** こちらはタグを付け替えた
    # 本文を送り直す経路で、**添付を持たない投稿にも来る**。一律に要求すると
    # 本文だけのタグ書き換えが 422 になる（PR #4590 の Codex P2）。
    #
    # 逆に ALT 編集側（nil / '' / `media_update`）では必須。欠けると
    # `flatten_media_attributes` が nil を each して落ちるうえ、そもそも
    # 「何も変えない PUT」にしかならない。
    def validate_status_update!(purpose, params)
      unless STATUS_UPDATE_PURPOSES.member?(purpose)
        raise Ginseng::ValidateError, "unknown purpose: #{purpose}"
      end
      attributes = params[:media_attributes]
      if purpose == 'tag'
        return if params[:status].present? || attributes.present?
        raise Ginseng::ValidateError, 'status or media_attributes is required'
      end
      raise Ginseng::ValidateError, 'media_attributes is required' if attributes.blank?
    end

    def create_status_update_body(purpose, params)
      return create_media_update_body(params) unless purpose == 'tag'
      return {status: params[:status], media_attributes: params[:media_attributes]}.compact
    end

    # ALT 編集 (#4589) で SNS へ送る body。
    #
    # ⚠ **現状維持したい値も明示的に送り直すこと。** Mastodon の
    # `UpdateStatusService` は「送らなかったパラメータ」を現状維持ではなく
    # **「空で更新」**として扱う。コントローラの `update_options` がハッシュ
    # リテラルなので、値が nil でも `options.key?` は常に true になるため。
    #
    # 落とすと ALT が反映されないどころか投稿が壊れる:
    #
    # - `media_ids` … `validate_media!` が `[]` を返し `media_attributes` の
    #   ループが対象を見つけられず **ALT が適用されない**うえ、
    #   `ordered_media_attachment_ids = []` で **投稿から添付が全部外れる**
    # - `spoiler_text` … **CW が消える**（`/source` が返しているのに未使用だった）
    # - `sensitive` … **閲覧注意フラグが外れる**
    #
    # `/source` は本文と CW しか返さないので、添付の順序と閲覧注意は
    # `fetch_status` から取る（リクエストが 1 本増える）。
    #
    # ⚠ `poll` も同じ構造（空なら `previous_poll.destroy`）だが、Mastodon は
    # 添付とアンケートを同時に持てないため ALT 編集では到達しない。`tag` purpose
    # を実装するときは別途注意すること。
    def create_media_update_body(params)
      headers = upstream_headers
      source = sns.fetch_status_source(params[:id], {headers:})
      status = sns.fetch_status(params[:id], {headers:})
      return {
        status: source['text'],
        spoiler_text: source['spoiler_text'].to_s,
        sensitive: status['sensitive'] ? true : false,
        media_ids: Array(status['media_attachments']).map {|v| v['id']},
        media_attributes: params[:media_attributes],
      }
    end

    # モロヘイヤ自身が上流 Mastodon を叩くときのヘッダ (#4621)。
    #
    # ⚠ **クライアントの `X-Mulukhiya-Purpose` を引き継がない。** これは
    # 「この要求はモロヘイヤへ通してよい」と nginx へ名乗るためのヘッダで、
    # 上流へ出ていく要求には意味が無い。
    #
    # 引き継ぐと、vhost に #4474 以前の `if ($http_x_mulukhiya_purpose != '')`
    # が残っている環境で **モロヘイヤ自身の内部 fetch が :3008 へ送り返されて
    # ループし、GET が 404 になる**（ステージングで実際に起きた）。
    # ⚠ `/source` は location の正規表現に一致せず素通りして 200 だったため、
    # **`/source` は通るのに `fetch_status` だけ落ちる**という非対称になり
    # 気づきにくい。正しい nginx なら無害だが、名乗る理由が無いものは出さない。
    def upstream_headers
      return @headers.except('X-Mulukhiya-Purpose')
    end

    def token
      return @headers['Authorization'].split(/\s+/).last if @headers['Authorization']
      return @headers['HTTP_AUTHORIZATION'].split(/\s+/).last if @headers['HTTP_AUTHORIZATION']
      return nil
    end

    # 413 はユーザーのファイルサイズ超過であり系の不具合ではないため、モロヘイヤ側の
    # 文言を出して alert も立てない。上流（nginx）が HTML を返すことが多く透過しても
    # 読めないうえ、「上限を超過している」はクライアント共通で出せる説明だから
    # (#4480 で透過へ寄せた後もここは残す)。
    #
    # ⚠ **413 を silent_statuses に並べない** (#4537)。ここへ来る時点で 413 は
    # 下の分岐で処理済みなので効かず、並べてあると「413 も抑止対象」と誤読する。
    # 401 の抑止は handle_gateway_error の既定に含まれている。
    #
    # ⚠ **このメソッドに届くかどうかは gem 側の実装に握られている** (#4594)。
    # ginseng-fediverse 1.8.28 より前の `MastodonService#upload` は上流の
    # `GatewayError` を `ValidateError` に詰め替えていたため、呼び出し元の
    # `rescue Ginseng::GatewayError` を素通りし、401 の抑止も下の 413 分岐も
    # **一度も到達していなかった**（ボットの無効トークン連打がそのまま管理者への
    # アラートメールになった）。境界は
    # `test/unit/service/mastodon_upload_error_boundary.rb` で押さえてある。
    def handle_upload_gateway_error(error)
      return handle_gateway_error(error) unless error.source_status == 413
      @renderer.message = {error: 'アップロードしたファイルがサーバーの上限サイズを超過しています。'}
      return @renderer.status = 413
    end
  end
end
