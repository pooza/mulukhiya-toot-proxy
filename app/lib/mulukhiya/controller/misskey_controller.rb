module Mulukhiya
  class MisskeyController < Controller
    include ControllerMethods

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
      e.alert unless e.source_status == 401
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
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
      e.alert unless e.source_status == 401
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
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
      e.alert unless e.source_status == 401
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
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
      # お気に入りは冪等操作。上流が 400 (大半は ALREADY_FAVORITED) を返しても、
      # 呼び出し後 note は必ずお気に入り状態にあるため成功として扱う。
      # Ginseng::HTTP は上流ボディを捨てて "Bad response 400" にするため
      # ALREADY_FAVORITED か否かは判別できないが、favorites/create の 400 は
      # 実質これに限られる (capsicum #565)。
      if e.source_status == 400
        # 完全無音だと冪等吸収の頻度・偏りを追えないため info ログを残す (#4394)。
        Logger.new.info(misskey_favorite: {
          event: 'idempotent_400',
          account_id: sns.account&.id,
          note_id: params[:noteId],
        })
        @renderer.message = {}
        @renderer.status = 200
        return @renderer.to_s
      end
      e.alert unless e.source_status == 401
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
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
      e.alert unless e.source_status == 401
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
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
    def handle_upload_gateway_error(error)
      error.alert unless [401, 413].include?(error.source_status)
      if error.source_status == 413
        @renderer.message = {error: 'アップロードしたファイルがサーバーの上限サイズを超過しています。'}
      else
        @renderer.message = {error: error.message}
      end
      return @renderer.status = error.source_status
    end
  end
end
