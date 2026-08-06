module Mulukhiya
  class MisskeyController < Controller
    include ControllerMethods

    # ユーザー起因で日常的に起きる Misskey のエラーコード。系の不具合ではないので
    # Sentry alert を抑止する（アップロードの 413 を抑止しているのと同じ判断、#4480）。
    #
    # 出典は Misskey 本体 `packages/backend/src/server/api/endpoints/` の
    # notes/create・notes/drafts/{create,update}・notes/favorites/create・
    # notes/reactions/create・drive/files/create が宣言する errors。
    # **モロヘイヤが横取りしているエンドポイントの分だけ**を列挙する。
    # 上流が新しいコードを足しても alert が出るだけで壊れないので、追従は随時でよい。
    USER_FAULT_CODES = [
      'ACCESS_DENIED',
      'ALREADY_FAVORITED',
      'ALREADY_REACTED',
      'CANNOT_CREATE_ALREADY_EXPIRED_POLL',
      'CANNOT_REACT_TO_RENOTE',
      'CANNOT_RENOTE',
      'CANNOT_RENOTE_DUE_TO_VISIBILITY',
      'CANNOT_RENOTE_OUTSIDE_OF_CHANNEL',
      'CANNOT_RENOTE_TO_A_PURE_RENOTE',
      'CANNOT_RENOTE_TO_EXTERNAL',
      'CANNOT_REPLY_TO_AN_INVISIBLE_NOTE',
      'CANNOT_REPLY_TO_A_PURE_RENOTE',
      'CANNOT_REPLY_TO_SPECIFIED_NOTE_WITH_EXTENDED_VISIBILITY',
      'CANNOT_REPLY_TO_SPECIFIED_VISIBILITY_NOTE_WITH_EXTENDED_VISIBILITY',
      'CONTAINS_PROHIBITED_WORDS',
      'CONTAINS_TOO_MANY_MENTIONS',
      'INAPPROPRIATE',
      'INVALID_FILE_NAME',
      'MAX_FILE_SIZE_EXCEEDED',
      'NO_FREE_SPACE',
      'NO_SUCH_CHANNEL',
      'NO_SUCH_FILE',
      'NO_SUCH_NOTE',
      'NO_SUCH_NOTE_DRAFT',
      'NO_SUCH_RENOTE',
      'NO_SUCH_RENOTE_TARGET',
      'NO_SUCH_REPLY',
      'NO_SUCH_REPLY_TARGET',
      'SCHEDULED_AT_MUST_BE_IN_FUTURE',
      'SCHEDULED_AT_REQUIRED',
      'TOO_MANY_DRAFTS',
      'TOO_MANY_SCHEDULED_NOTES',
      'UNALLOWED_FILE_TYPE',
      'YOU_HAVE_BEEN_BLOCKED',
    ].freeze

    post '/api/notes/create' do
      verify_token_integrity!
      params[visibility_field] = status_class[params[:renoteId]][visibility_field.to_sym] if quote?
      params[visibility_field] = self.class.visibility_name(:unlisted) if channel?
      Event.new(:pre_toot, {reporter:, sns:}).dispatch(params) unless renote?
      reporter.response = sns.note(params)
      verify_account_integrity!(reporter.response)
      Event.new(renote? ? :post_boost : :post_toot, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_gateway_error(e, silent_codes: USER_FAULT_CODES)
      return @renderer.to_s
    end

    post '/api/notes/drafts/create' do
      verify_token_integrity!
      params[visibility_field] = status_class[params[:renoteId]][visibility_field.to_sym] if quote?
      params[visibility_field] = self.class.visibility_name(:unlisted) if channel?
      Event.new(:pre_toot, {reporter:, sns:}).dispatch(params) unless renote?
      reporter.response = sns.draft(params)
      verify_account_integrity!(reporter.response)
      Event.new(renote? ? :post_boost : :post_toot, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_gateway_error(e, silent_codes: USER_FAULT_CODES)
      return @renderer.to_s
    end

    post '/api/notes/drafts/update' do
      verify_token_integrity!
      if params[:text].present?
        if quote?
          params[visibility_field] = status_class[params[:renoteId]][visibility_field.to_sym]
        end
        params[visibility_field] = self.class.visibility_name(:unlisted) if channel?
        Event.new(:pre_draft, {reporter:, sns:}).dispatch(params) unless renote?
      end
      reporter.response = sns.update_draft(params)
      verify_account_integrity!(reporter.response)
      if params[:text].present?
        Event.new(renote? ? :post_boost : :post_toot, {reporter:, sns:}).dispatch(params)
      end
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_gateway_error(e, silent_codes: USER_FAULT_CODES)
      return @renderer.to_s
    end

    post '/api/drive/files/create' do
      verify_token_integrity!
      Event.new(:pre_upload, {reporter:, sns:}).dispatch(params)
      reporter.response = sns.upload(params.dig(:file, :tempfile), {
        name: params[:name],
        comment: params[:comment],
        isSensitive: params[:isSensitive],
        folderId: params[:folderId],
      }.compact)
      Event.new(:post_upload, {reporter:, sns:}).dispatch(params)
      @renderer.message = JSON.parse(reporter.response.body)
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_upload_gateway_error(e)
      return @renderer.to_s
    end

    post '/api/notes/favorites/create' do
      verify_token_integrity!
      reporter.response = sns.fav(params[:noteId])
      Event.new(:post_bookmark, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response || {}
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      # お気に入りは冪等操作。ALREADY_FAVORITED なら呼び出し後 note は必ず
      # お気に入り状態にあるため成功として扱う (capsicum#565 / #4381)。
      #
      # ⚠ かつては **400 を全部**丸めていた。上流ボディが捨てられていて
      # ALREADY_FAVORITED か否かを判別できなかったためで、NO_SUCH_NOTE
      # （不正な id）まで成功と偽っていた。#4480 で code が読めるようになった
      # ので、丸めるのは ALREADY_FAVORITED だけに絞る。
      if upstream_error_code(e) == 'ALREADY_FAVORITED'
        # 完全無音だと冪等吸収の頻度・偏りを追えないため info ログを残す (#4394)。
        Logger.new.info(misskey_favorite: {
          event: 'idempotent_already_favorited',
          account_id: sns.account&.id,
          note_id: params[:noteId],
        })
        @renderer.message = {}
        @renderer.status = 200
        return @renderer.to_s
      end
      handle_gateway_error(e, silent_codes: USER_FAULT_CODES)
      return @renderer.to_s
    end

    post '/api/notes/reactions/create' do
      verify_token_integrity!
      reporter.response = sns.reaction(params[:noteId], params[:reaction])
      Event.new(:post_reaction, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response || {}
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_gateway_error(e, silent_codes: USER_FAULT_CODES)
      return @renderer.to_s
    end

    def renote?
      return params[:renoteId].present? && params[:text].empty?
    end

    def quote?
      return params[:renoteId].present? && params[:text].present?
    end

    def channel?
      return params[:channelId].present?
    end

    get '/api/mulukhiya/diag' do
      @renderer.message = token_echo_response
      return @renderer.to_s
    end

    def token
      return @headers['Authorization'].split(/\s+/).last if @headers['Authorization']
      return @headers['HTTP_AUTHORIZATION'].split(/\s+/).last if @headers['HTTP_AUTHORIZATION']
      return params[:i]
    end

    # 413 はユーザーのファイルサイズ超過であり系の不具合ではないため Sentry alert を抑止する。
    # 401 は既存どおりトークン期限切れ等で頻繁に起きるため除外する。
    #
    # 413 だけはモロヘイヤ側の文言を出す。上流（nginx）が HTML を返すことが多く
    # 透過しても読めないうえ、「上限を超過している」はクライアント共通で出せる
    # 説明だから (#4480 で透過へ寄せた後もここは残す)。
    def handle_upload_gateway_error(error)
      unless error.source_status == 413
        return handle_gateway_error(
          error,
          silent_statuses: [401, 413],
          silent_codes: USER_FAULT_CODES,
        )
      end
      @renderer.message = {error: 'アップロードしたファイルがサーバーの上限サイズを超過しています。'}
      return @renderer.status = 413
    end
  end
end
