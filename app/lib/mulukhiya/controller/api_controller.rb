module Mulukhiya
  class APIController < Controller
    get '/about' do
      sns.token ||= sns.default_token
      about = config.about
      about[:config][:theme] = {color: sns.theme_color}
      about[:config][:handlers] = (Handler.all_names || [])
        .reject {|name| config["/handler/#{name}/disable"] == true rescue false}
        .sort.to_a
      # server レベルの静的 features に、ユーザー単位・実行時状態の動的フラグを
      # 合流させる。フラグの定義は DynamicFeatures::REGISTRY に集約 (#4348)。
      about[:config][:features] = about[:config][:features].merge(DynamicFeatures.new(sns).to_h)
      @renderer.message = about
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/health' do
      sns.token ||= sns.default_token
      @renderer.message = Environment.health
      @renderer.status = @renderer.message[:status] || 200
      return @renderer.to_s
    end

    get '/config' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      sns.account.user_config.token = token
      @renderer.message = {
        account: sns.account.to_h,
        config: sns.account.user_config.to_h,
        # ⚠ トークンを持たないアカウントでは `Account#webhook` が Webhook を
        # 返しても URL は作れない (#4487)。直前の user_config.token 代入が失敗した
        # 場合に `ConfigError` → 500 へ化けるので、`available?` で分岐して null を
        # 返す。docs/api.md に nullable と明記してある (#4537)。
        webhook: {url: webhook_url},
        token: sns.access_token.to_h.except(:account),
        visibility_names: parser_class.visibility_names,
      }
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/config/update' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      Handler.create(:user_config_command).handle_toot(params, {sns:})
      @renderer.message = {config: sns.account.user_config.to_h}
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    # 投稿テンプレート（定形投稿）の per-user CRUD (#4457, pooza/capsicum#767)。
    # 保存先は user_config の `/compose/templates`。書き込み結果は
    # ComposeTemplateContainer が read-back で検証し、失敗時は 5xx を返す。
    get '/compose/templates' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      @renderer.message = {templates: ComposeTemplateContainer.new(sns.account).all}
      return @renderer.to_s
    rescue => e
      # 認証失敗 (403) 等の想定内 4xx は log、read 経路の真の 5xx（Redis 障害等）は
      # write 系と対称に alert する。
      e.status < 500 ? e.log : e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/compose/templates' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      errors = ComposeTemplateContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
        return @renderer.to_s
      end
      container = ComposeTemplateContainer.new(sns.account)
      template = container.create(params)
      @renderer.message = {template:, templates: container.all}
      return @renderer.to_s
    rescue => e
      # 上限超過 (409) 等の想定内クライアントエラーは log に留め、保存失敗 (5xx) だけ
      # alert する（想定内 4xx で Sentry を汚さない）。
      e.status < 500 ? e.log : e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    put '/compose/templates/:id' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      errors = ComposeTemplateContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
        return @renderer.to_s
      end
      container = ComposeTemplateContainer.new(sns.account)
      template = container.update(params[:id], params)
      @renderer.message = {template:, templates: container.all}
      return @renderer.to_s
    rescue => e
      e.status < 500 ? e.log : e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    delete '/compose/templates/:id' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      container = ComposeTemplateContainer.new(sns.account)
      template = container.delete(params[:id])
      @renderer.message = {template:, templates: container.all}
      return @renderer.to_s
    rescue => e
      # 既に削除済み (404) は race で起こる想定内。log に留める。
      e.status < 500 ? e.log : e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/mastodon/auth' do
      raise Ginseng::NotFoundError, 'Not Found' unless Environment.mastodon_type?
      errors = MastodonAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        response = sns.auth(params[:code], params[:type])
        @renderer.message = response.parsed_response
        @renderer.message['access_token_crypt'] = @renderer.message['access_token'].encrypt
      end
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/misskey/auth' do
      raise Ginseng::NotFoundError, 'Not Found' unless Environment.misskey_type?
      errors = MisskeyAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        response = sns.auth(params[:code], params[:type])
        token = sns.create_access_token(response.parsed_response['accessToken'], params[:type])
        @renderer.message = response.parsed_response
        @renderer.message['access_token_crypt'] = token.encrypt
      end
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/sw/register' do
      raise Ginseng::NotFoundError, 'Not Found' unless Environment.misskey_type?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      unless sns.access_token&.scopes&.include?('write:account')
        raise Ginseng::AuthError, 'Permission denied'
      end
      errors = SwSubscriptionContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
        return @renderer.to_s
      end
      limit_max = config['/misskey/sw_subscription/rate_limit/max']
      limit_window = config['/misskey/sw_subscription/rate_limit/window']
      count = RateLimitStorage.new.increment("sw_register:#{sns.account.id}", window: limit_window)
      if count > limit_max
        @renderer.status = 429
        @renderer.message = {error: 'Too Many Requests'}
        return @renderer.to_s
      end
      result = sns.register_sw_subscription(sns.account, params)
      subscription = result[:subscription]
      @renderer.message = {
        state: result[:state].to_s.tr('_', '-'),
        userId: subscription.userId,
        endpoint: subscription.endpoint,
        sendReadMessage: subscription.sendReadMessage,
      }
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/sw/unregister' do
      raise Ginseng::NotFoundError, 'Not Found' unless Environment.misskey_type?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      unless sns.access_token&.scopes&.include?('write:account')
        raise Ginseng::AuthError, 'Permission denied'
      end
      errors = SwSubscriptionContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
        return @renderer.to_s
      end
      removed = sns.unregister_sw_subscription(sns.account, params)
      @renderer.message = {state: removed ? 'unsubscribed' : 'not-subscribed'}
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/emoji/palettes' do
      raise Ginseng::NotFoundError, 'Not Found' unless Environment.misskey_type?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      @renderer.message = sns.emoji_palettes(sns.account)
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/decoration/list' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.decoration?
      sns.token ||= sns.default_token
      @renderer.message = sns.fetch_avatar_decorations
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/decoration/restore' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.decoration?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      saved = sns.account.user_config['/decoration/saved_state']
      raise Ginseng::NotFoundError, 'Not Found' unless saved.present?
      DecorationInitializeWorker.new.restore_decoration(sns.account)
      @renderer.message = {config: sns.account.user_config.to_h}
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/program' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.livecure?
      sns.token ||= sns.default_token
      # 放送順 (next_on → start_time) で返す (#4540)。キーは SHA256 の先頭 12 桁
      # 固定で JS の配列インデックス (2**32-1 以下) にならないため、オブジェクトの
      # ままでもクライアント側で挿入順が保たれる。
      @renderer.message = Program.instance.sorted_data
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    # 番組表を iCalendar で公開する (#4287)。tomato-shrieker の IcalendarSource
    # から購読される想定で認証不要。GET /program と同じく livecure? でゲートする。
    get '/program.ics' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.livecure?
      @renderer = ProgramCalendarRenderer.new
      return @renderer.to_s
    rescue => e
      # 404 (非対応サーバー) は期待動作なので log のみ。tomato-shrieker が定期 GET する
      # 外部購読先なので、5xx の恒常失敗は検知できるよう alert に昇格する (#4394)。
      if e.is_a?(Ginseng::NotFoundError)
        e.log
      else
        e.alert
      end
      @renderer = default_renderer_class.new
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/program/update' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.livecure?
      ProgramUpdateWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/program/works' do
      annict = sns.account&.annict || account_class.info_account.annict
      raise Ginseng::AuthError, 'Unauthorized' unless annict
      errors = AnnictWorkListContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        @renderer.message = annict.works(params[:q]).map do |work|
          values = work.deep_symbolize_keys
          values[:officialSiteUrl] = values[:officialSiteUrl].to_s if values[:officialSiteUrl]
          values
        end
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/program/works/:id/episodes' do
      raise Ginseng::AuthError, 'Unauthorized' unless annict = account_class.info_account.annict
      @renderer.message = annict.episodes([params[:id].to_i]).map do |episode|
        episode.merge(
          url: episode['url'].to_s,
          hashtag_url: episode['hashtag_uri'].to_s,
          command_toot: episode['command_toot'],
        )
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/media' do
      # media_catalog 無効時は 404 ではなく 503 + 空リスト + available:false を返す
      # (#4343)。404 = 「このサーバーではエンドポイント自体が提供されていない」、
      # 503 = 「機能はあるが現在 OFF」をクライアント（capsicum 等）が区別できるよう
      # にするため。features.media_catalog と組合せて利用する想定。
      unless controller_class.media_catalog?
        MediaCatalogDisabledRenderer.apply!(@renderer, endpoint: '/media')
        return @renderer.to_s
      end
      sns.token ||= sns.default_token
      # only_person は旧来 .to_i 経由で boolean 風文字列 ('true'/'false' 等) を 0/1
      # に丸める寛容な仕様だった。Contract 検証 (5.22.0 #4283 切出し時に検証順を
      # 変更) で 422 になる経路を再導入しないよう、検証前に正規化しておく。
      params[:only_person] = (params[:only_person] || 0).to_i.zero? ? 0 : 1
      params.delete(:q) unless sns.account
      errors = MediaListContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        @renderer.message = MediaCatalogQueryService.new.call(params)
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/media/file/clear' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      MediaCleaningWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/media/metadata/clear' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      MediaMetadataStorage.new.clear
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/status/list' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.account_timeline?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      params[:limit] ||= config['/webui/status/timeline/limit']
      params[:page] = (params[:page] || 1).to_i
      params[:self] = (params[:self] || 0).to_i.zero? ? 0 : 1
      params.delete(:q) unless params[:q].present?
      errors = StatusListContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        params[:rule] = SearchRule.new(params[:q]) if params[:q]
        @renderer.message = sns.account.statuses(params)
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/status/:id' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      raise Ginseng::NotFoundError, 'Not Found' unless status = status_class[params[:id]]
      raise Ginseng::AuthError, 'Unauthorized' unless status.updatable_by?(sns.account)
      @renderer.message = status.to_h.merge(
        account: status.account.to_h.slice(:username, :display_name, :acct),
      )
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/status/tags' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.repost?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      raise Ginseng::NotFoundError, 'Not Found' unless status = status_class[params[:id]]
      raise Ginseng::AuthError, 'Unauthorized' unless status.updatable_by?(sns.account)
      errors = StatusTagsContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        @renderer.message = StatusTagAddService.new(sns).call(status, params[:tags])
      end
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      # 上流の 4xx を 502 に潰さない。潰すと capsicum が「本文が長すぎる」と
      # 「SNS が落ちている」を区別できない (#4491 の docs 記述に実装を揃える)。
      e.log
      @renderer.status = e.respond_to?(:source_status) ? e.source_status : 502
      @renderer.message = {error: e.message}
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    put '/scheduled_status/:id/tags' do
      raise Ginseng::NotFoundError, 'Not Found' unless Environment.mastodon_type?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      storage = ScheduledStatusStorage.new
      entry = storage.get(params[:id])
      raise Ginseng::NotFoundError, 'Not Found' unless entry
      raise Ginseng::AuthError, 'Unauthorized' unless entry[:account_id] == sns.account.id
      errors = ScheduledStatusTagsContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        updater = ScheduledStatusTagUpdater.new(sns, storage)
        @renderer.message = updater.call(params[:id], entry, params[:tags])
      end
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.log
      @renderer.status = e.respond_to?(:source_status) ? e.source_status : 502
      @renderer.message = {error: e.message}
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    delete '/status/nowplaying' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      raise Ginseng::NotFoundError, 'Not Found' unless status = status_class[params[:id]]
      raise Ginseng::AuthError, 'Unauthorized' unless status.updatable_by?(sns.account)
      raise Ginseng::NotFoundError, 'Not Found' unless body = status.parser.body
      errors = StatusContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        @renderer.message = sns.repost(status, NowplayingHandler.trim(body))
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/nowplaying/resolve' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      errors = NowplayingResolveContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
        return @renderer.to_s
      end
      resolver = NowplayingResolver.new(
        title: params[:title],
        artist: params[:artist],
        album: params[:album],
        source_app_name: params[:source_app_name],
        prefer: params[:prefer],
      )
      @renderer.message = resolver.resolve
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/nowplaying/resolve-url' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      errors = NowplayingResolveUrlContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
        return @renderer.to_s
      end
      @renderer.message = NowplayingUrlResolver.new(url: params[:url]).resolve
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/annict/oauth_uri' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.annict?
      @renderer.message = {oauth_uri: AnnictService.new.oauth_uri.to_s}
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/annict/auth' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.annict?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      errors = AnnictAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        response = AnnictService.new.auth(params[:code])
        sns.account.user_config.update(service: {annict: {token: response['access_token']}})
        sns.account.annict.clear
        sns.account.annict.updated_at = Time.now
        @renderer.status = response.code
        @renderer.message = {config: sns.account.user_config.to_h}
      end
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/spotify/oauth_uri' do
      raise Ginseng::NotFoundError, 'Not Found' unless SpotifyUserService.config?
      @renderer.message = {oauth_uri: SpotifyUserService.new.oauth_uri.to_s}
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/spotify/auth' do
      raise Ginseng::NotFoundError, 'Not Found' unless SpotifyUserService.config?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      errors = SpotifyAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        SpotifyUserService.new(sns.account).auth(params[:code])
        @renderer.message = {config: sns.account.user_config.to_h}
      end
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/spotify/currently_playing' do
      raise Ginseng::NotFoundError, 'Not Found' unless SpotifyUserService.config?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      spotify = sns.account.spotify
      raise Ginseng::AuthError, 'Spotify authentication required' unless spotify
      @renderer.message = {url: spotify.currently_playing}
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.log
      @renderer.status = e.respond_to?(:source_status) ? e.source_status : 502
      @renderer.message = {error: e.message}
      return @renderer.to_s
    rescue Ginseng::AuthError => e
      # 未連携・refresh_token 失効は想定内のユーザー状態。capsicum が定期ポーリング
      # するため alert すると Sentry スパム化する。log に留め 403 で返す。
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    delete '/spotify/auth' do
      raise Ginseng::NotFoundError, 'Not Found' unless SpotifyUserService.config?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      sns.account.spotify&.unlink
      @renderer.message = {config: sns.account.user_config.to_h}
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/annict/record' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.annict?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      annict = sns.account.annict
      raise Ginseng::AuthError, 'Annict authentication required' unless annict
      errors = AnnictRecordContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
        return @renderer.to_s
      end
      episode_id = params[:episode_id].to_i
      lock = AnnictRecordLockStorage.new
      lock_token = lock.acquire(sns.account.id, episode_id)
      unless lock_token
        raise Ginseng::ConflictError, 'Duplicate Annict record request is in progress'
      end
      begin
        record = annict.create_record(
          episode_id:,
          comment: params[:comment].presence,
          rating_state: params[:rating_state].presence,
        )
      rescue
        # createRecord 失敗時はロックを解放しリトライ可能にする
        # (record 未作成のため重複の懸念がない)。token を渡すことで TTL 跨ぎ後の
        # 他者ロック誤削除を防ぐ (#4345)。
        lock.release(sns.account.id, episode_id, lock_token)
        raise
      end
      @renderer.message = {record:}
      return @renderer.to_s
    rescue => e
      return handle_annict_write_error(
        e, kind: :annict_record, lock:, id_label: :episode_id, id_value: params[:episode_id]
      )
    end

    post '/annict/review' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.annict?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      annict = sns.account.annict
      raise Ginseng::AuthError, 'Annict authentication required' unless annict
      errors = AnnictReviewContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
        return @renderer.to_s
      end
      work_id = params[:work_id].to_i
      lock = AnnictReviewLockStorage.new
      lock_token = lock.acquire(sns.account.id, work_id)
      unless lock_token
        raise Ginseng::ConflictError, 'Duplicate Annict review request is in progress'
      end
      begin
        review = annict.create_review(
          work_id:,
          body: params[:body],
          rating_overall_state: params[:rating_overall_state].presence,
          rating_animation_state: params[:rating_animation_state].presence,
          rating_music_state: params[:rating_music_state].presence,
          rating_story_state: params[:rating_story_state].presence,
          rating_character_state: params[:rating_character_state].presence,
          share_twitter: params[:share_twitter],
          share_facebook: params[:share_facebook],
        )
      rescue
        # createReview 失敗時はロックを解放しリトライ可能にする (review 未作成のため
        # 重複の懸念がない)。token を渡し TTL 跨ぎ後の他者ロック誤削除を防ぐ (#4345)。
        lock.release(sns.account.id, work_id, lock_token)
        raise
      end
      @renderer.message = {review:}
      return @renderer.to_s
    rescue => e
      return handle_annict_write_error(
        e, kind: :annict_review, lock:, id_label: :work_id, id_value: params[:work_id]
      )
    end

    post '/announcement/update' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.announcement?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      AnnouncementWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    # capsicum-relay (capsicum-relay#14) からの公開キャッシュ参照用 (#4355)。
    # Redis にキャッシュ済みの SNS announcement 一覧を array で返す。認証不要。
    # shape は SNS 種別に依存し (Mastodon: content / published_at、Misskey:
    # title / text / createdAt)、capsicum-relay 側で正規化する。
    get '/announcement/list' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.announcement?
      @renderer.message = Announcement.new.load.values
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/tagging/favorites' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.favorite_tags?
      sns.token ||= sns.default_token
      @renderer.message = hash_tag_class.favorites
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/tagging/dic/update' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      TaggingDictionaryUpdateWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/tagging/dic/annict/episodes' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.annict?
      raise Ginseng::AuthError, 'Unauthorized' unless annict = account_class.info_account.annict
      episodes = annict.episodes(annict.works.map {|v| v['annictId'].to_i})
      @renderer.message = episodes.filter_map do |e|
        title = e['title'].to_s.strip
        next if title.empty?
        if (m = e['numberText'].to_s[/\d+/])
          [title, ["#{m}話"]]
        else
          [title, []]
        end
      end.to_h
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/tagging/tag/search' do
      errors = TagSearchContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        @renderer.message = TagSearchService.new.search(params[:q])
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/tagging/usertag/clear' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      UserTagInitializeWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/word/suggest' do
      dictionary = PronunciationDictionary.new
      raise Ginseng::NotFoundError, 'Not Found' unless dictionary.enabled?
      errors = WordSuggestContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        @renderer.message = {candidates: dictionary.suggest(params[:q], limit: params[:limit])}
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    # 辞書全件取得 (capsicum 投稿サジェストの一括取得 + ローカル絞り込み #687 /
    # mulukhiya#4430)。word/suggest と同じ feature gate・公開・読み取り専用。
    # ETag (= digest) を付与し、If-None-Match 一致時は 304 で本文を返さない
    # (capsicum の一括取得キャッシュの再検証用)。
    get '/word/all' do
      dictionary = PronunciationDictionary.new
      raise Ginseng::NotFoundError, 'Not Found' unless dictionary.enabled?
      digest = dictionary.digest
      headers 'ETag' => %("#{digest}")
      if request.env['HTTP_IF_NONE_MATCH'].to_s.delete('"') == digest
        @renderer.status = 304
        return ''
      end
      @renderer.message = {words: dictionary.all, size: dictionary.size, digest:}
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/piefed/communities' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.piefed?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      @renderer.message = sns.account.piefed&.communities || {}
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/feed/list' do
      tags = TagContainer.new
      tags.merge(TagContainer.default_tags)
      tags.merge(TagContainer.media_tags)
      if sns.account
        tags.merge(sns.account.featured_tags)
        tags.merge(sns.account.followed_tags)
        tags.merge(sns.account.field_tags)
        tags.merge(sns.account.bio_tags)
      end
      @renderer.message = tags.map {|t| hash_tag_class.get(tag: t).to_h}.deep_compact
      return @renderer.to_s
    end

    post '/feed/update' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      FeedUpdateWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/admin/program/entry' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.livecure?
      errors = ProgramEntryContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
        return @renderer.to_s
      end
      attributes = params.to_h
        .slice(*ProgramEntryContract::WRITABLE_KEYS.map(&:to_s))
        .transform_keys(&:to_sym)
      key = params[:key].to_s
      key = Program.instance.generate_key(attributes) if key.empty?
      entry = Program.instance.add_entry(key, attributes)
      @renderer.message = {key:, entry:}
      return @renderer.to_s
    rescue => e
      handle_program_entry_error(e, params[:key])
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    put '/admin/program/entry/:key' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.livecure?
      errors = ProgramEntryUpdateContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
        return @renderer.to_s
      end
      attributes = params.to_h
        .slice(*ProgramEntryContract::WRITABLE_KEYS.map(&:to_s))
        .transform_keys(&:to_sym)
      entry = Program.instance.update_entry(params[:key], attributes)
      @renderer.message = {key: params[:key], entry:}
      return @renderer.to_s
    rescue => e
      handle_program_entry_error(e, params[:key])
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    delete '/admin/program/entry/:key' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.livecure?
      entry = Program.instance.delete_entry(params[:key])
      raise Ginseng::NotFoundError, "キー '#{params[:key]}' が見つかりません。" unless entry
      @renderer.message = {key: params[:key], entry:}
      return @renderer.to_s
    rescue => e
      handle_program_entry_error(e, params[:key])
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/admin/program/entry/:key/episode/increment' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.livecure?
      annict = sns.account&.annict || account_class.info_account&.annict
      entry = Program.instance.increment_episode(params[:key], annict: annict)
      @renderer.message = {key: params[:key], entry:}
      return @renderer.to_s
    rescue => e
      handle_program_entry_error(e, params[:key])
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/admin/program/entry/:key/next_on/advance' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.livecure?
      entry = Program.instance.advance_next_on(params[:key], days: params[:days])
      @renderer.message = {key: params[:key], entry:}
      return @renderer.to_s
    rescue => e
      handle_program_entry_error(e, params[:key])
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/admin/handler/list' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      @renderer.message = Handler.all.map do |handler|
        {
          name: handler.underscore,
          disable: config.disable?(handler),
          schema: handler.editable_schema,
          params: handler.editable_params,
        }
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/admin/handler/config' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      if params.key?(:flag)
        config.update_file(handler: {params[:handler] => {disable: params[:flag]}})
      elsif params.key?(:values)
        handler = Handler.create(params[:handler])
        validated = handler.validate_params(params[:values])
        config.update_file(handler: {params[:handler] => validated})
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/admin/config/audit' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      @renderer.message = config.audit
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/admin/agent/config' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      if params[:info_token]
        raise Ginseng::AuthError, 'Unauthorized' unless sns.account.admin? || sns.account.info?
        config.update_file(agent: {info: {token: params[:info_token]}})
      end
      if params[:test_token]
        raise Ginseng::AuthError, 'Unauthorized' unless sns.account.admin? || sns.account.test?
        config.update_file(agent: {test: {token: params[:test_token]}})
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/admin/puma/restart' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      PumaDaemonRestartWorker.perform_in(config['/puma/restart/seconds'], {})
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/account/is_cat' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      errors = IsCatContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
        return @renderer.to_s
      end
      storage = IsCatStorage.new
      http = HTTP.new
      result = Concurrent::Hash.new
      Parallel.each(params[:accts].uniq, in_threads: Parallel.processor_count) do |acct_str|
        acct = Ginseng::Fediverse::Acct.new(acct_str)
        cached = storage.get(acct_str)
        if cached
          result[acct_str] = cached['is_cat']
          next
        end
        actor = fetch_actor(http, acct)
        is_cat = actor&.dig('isCat')
        result[acct_str] = is_cat
        storage.set(acct_str, {is_cat:}) unless actor.nil?
      rescue => e
        e.log(acct: acct_str)
        result[acct_str] = nil
      end
      @renderer.message = result
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    def token
      return nil unless (header = @headers['Authorization']) && header =~ /\ABearer\s+(\S+)/i
      bearer = Regexp.last_match(1)
      plain = bearer.decrypt rescue bearer
      return nil if plain.to_s.empty?
      return plain
    end

    def self.default_type
      return 'application/json; charset=UTF-8'
    end

    private

    # webhook URL。トークンが無いアカウントでは nil を返す (#4487 / #4537)。
    def webhook_url
      webhook = sns.account.webhook
      return nil unless webhook.available?
      return webhook.uri.to_s
    end

    # Annict record/review の rescue 共通処理。書き込み系 (createRecord/createReview)
    # の失敗は /admin/program/entry 系 (#4255) と整合させ Sentry へ到達させる。ただし
    # 冪等性ロック由来の 409 は期待動作なので info ログのみとし (#4330)、同一アカウントが
    # 1 分間に alert_threshold 件 (既定 10) に達したらリトライループ異常として alert 昇格
    # する (#4346)。未認証・未連携等ユーザー入力起因の 403/404 は alert spam を避け log
    # のみ (#4265)。kind は :annict_record / :annict_review、id_label/id_value は
    # episode_id / work_id の文脈。
    # 番組表編集 5 本の rescue (#4629)。
    #
    # ⚠⚠ **`AuthError` と `NotFoundError` が `else` へ落ちて alert していた。**
    # 無効トークン・非管理者トークンで叩かれるたびに Sentry イベントと管理者への
    # アラートメールが飛ぶ形で、#4594 でボットの 401 連打が実際にメール化したのと
    # 同じ。非 livecure サーバーへの誤アクセスも 404 で毎回鳴っていた。
    #
    # ⚠ **同じ rescue が 5 本に複写されていたのが取りこぼしの原因**なので、
    # クラスを足すのではなくヘルパへ寄せた。判定の本体は `report_error`
    # （ステータスで見るので新しい 4xx を投げても漏れない）。
    #
    # 409 / 422 だけ構造化ログを残すのは、期待動作として頻度を追いたいため。
    def handle_program_entry_error(error, key)
      case error
      when Ginseng::ConflictError
        # 409 (auto_update? 有効時 / 重複キー / 書き込みロック競合 #4534)
        Logger.new.info(program_entry: {event: 'conflict', key:, message: error.message})
      when Ginseng::ValidateError
        # 422 (days が不正 等)
        Logger.new.info(program_entry: {event: 'invalid', key:, message: error.message})
      else
        report_error(error)
      end
    end

    def handle_annict_write_error(error, kind:, lock:, id_label:, id_value:)
      if error.is_a?(Ginseng::ConflictError)
        handle_annict_conflict(error, kind:, lock:, id_label:, id_value:)
      elsif error.is_a?(Ginseng::AuthError) || error.is_a?(Ginseng::NotFoundError)
        error.log
      else
        error.alert
      end
      @renderer.status = error.status
      @renderer.message = {error: error.message}
      return @renderer.to_s
    end

    # 冪等性ロック由来の 409 は info ログのみ。同一アカウントが 1 分間に
    # alert_threshold 件に達したらリトライループ異常として alert 昇格する (#4346)。
    def handle_annict_conflict(error, kind:, lock:, id_label:, id_value:)
      Logger.new.info(kind => {
        event: 'conflict',
        account_id: sns.account&.id,
        id_label => id_value,
      })
      return unless sns.account && lock.record_conflict(sns.account.id, id_value.to_i)
      error.alert(kind => {
        event: 'conflict_threshold_exceeded',
        account_id: sns.account.id,
        id_label => id_value,
        threshold: lock.alert_threshold,
      })
    end

    # webfinger → actor の 2 段取得 (#4198)。**外部から与えられた acct のホストへ
    # モロヘイヤが接続する**経路なので、SSRF ガードは 2 重に要る (#4576):
    #
    #   1. 取得前の事前判定 (RemoteHost.validate!) — 拒否をここで確定させる
    #   2. 取得中の各ホップ検証 + pinning (host_validator)
    #
    # ⚠ **事前判定だけでは足りない。**host_validator を渡さないと Ginseng::HTTP は
    # 素の HTTParty 経路へ落ち、**既定でリダイレクトを追従する**（limit 5）。
    # 攻撃者のホストが `302 Location: http://127.0.0.1:9200/` を返せば、
    # 検証済みホストの裏から内部サービスへ到達できる (#4410 と同じ形)。
    # ⚠ **pinning が無いと名前を二度引くことになる。**検証時だけ公開アドレスを
    # 返し、接続時に 127.0.0.1 を返す DNS リバインディングが通る (#4524)。
    #
    # ⚠ **拒否は nil ではなくログを残して nil。**呼び出し元は acct ごとに nil を
    # 「判定不能」として返すので、黙って nil にすると攻撃の試行が一切見えない。
    def fetch_actor(http, acct)
      RemoteHost.validate!(acct.host)
      url = "https://#{acct.host}/.well-known/webfinger?resource=acct:#{acct}"
      webfinger = fetch_json(http, url, 'application/jrd+json')
      actor_uri = webfinger['links']&.find do |l|
        l['type'] == 'application/activity+json'
      end&.dig('href')
      return nil unless actor_uri
      RemoteHost.validate!(Ginseng::URI.parse(actor_uri)&.host.to_s)
      return fetch_json(http, actor_uri, 'application/activity+json')
    rescue => e
      e.log(acct: acct.to_s)
      return nil
    end

    def fetch_json(http, url, accept)
      response = http.get(url, {
        headers: {'Accept' => accept},
        host_validator: RemoteHost.validator,
      }).parsed_response
      return response.is_a?(String) ? JSON.parse(response) : response
    end
  end
end
