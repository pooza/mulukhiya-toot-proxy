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

    post '/api/:version/statuses' do
      verify_token_integrity!
      tags = TootParser.new(params[:status]).tags
      Event.new(:pre_toot, {reporter:, sns:}).dispatch(params)
      reporter.response = sns.toot(params)
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
      case purpose
      when nil, '', 'media_update'
        source = sns.fetch_status_source(params[:id], {headers: @headers})
        body = {status: source['text'], media_attributes: params[:media_attributes]}.compact
      when 'tag'
        body = {status: params[:status], media_attributes: params[:media_attributes]}.compact
      else
        raise Ginseng::ValidateError, "unknown purpose: #{purpose}"
      end
      raise Ginseng::ValidateError, 'media_attributes is required' if body.empty?
      reporter.response = sns.update_status(params[:id], body, {headers: @headers})
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
    def handle_upload_gateway_error(error)
      return handle_gateway_error(error) unless error.source_status == 413
      @renderer.message = {error: 'アップロードしたファイルがサーバーの上限サイズを超過しています。'}
      return @renderer.status = 413
    end
  end
end
