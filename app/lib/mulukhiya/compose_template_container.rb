module Mulukhiya
  # 投稿テンプレート（定形投稿）の per-user CRUD (#4457, pooza/capsicum#767)。
  # 保存先は user_config の `/compose/templates`（モロヘイヤ自身の Redis・db 1）で、
  # `/tagging/user_tags`・`/decoration/saved_state` と同じ per-user storage の系譜。
  #
  # UserConfig#update が例外を握りつぶす（`rescue => e; e.alert`）ため、書き込み後に
  # read-back で永続化を検証し、失敗時は GatewayError を上げて capsicum に返す。
  # これが専用エンドポイントにした主目的＝「保存したのに消えた」を検知可能にする点。
  class ComposeTemplateContainer
    include Package

    # 1 アカウントあたりの上限。user_config への書き込みは Redis SAVE（同期・全体
    # ブロッキング）を伴うため、青天井の blob をサーバー側で止める (#4457)。
    MAX_COUNT = 50
    # 保存・出力で保持するフィールド。`id` はサーバー採番なので照合対象に含めない。
    FIELDS = ['name', 'body', 'cw'].freeze

    def initialize(account)
      @account = account
    end

    def all
      return Array(user_config['/compose/templates']).grep(Hash)
    end

    def find(id)
      return all.find {|v| v['id'].to_s == id.to_s}
    end

    # 以下 3 メソッドは read-modify-write なので、多端末同時書き込みの lost update
    # を防ぐため account 単位のロックで直列化する（保持中は 409、#4457/#4460）。
    def create(attributes)
      lock.synchronize(@account.id) do
        templates = all
        raise Ginseng::ConflictError, "テンプレートは最大 #{MAX_COUNT} 件までです。" if templates.size >= MAX_COUNT
        template = normalize(attributes).merge('id' => SecureRandom.uuid)
        persist(templates + [template])
        saved = find(template['id'])
        raise Ginseng::GatewayError, 'テンプレートを保存できませんでした。' unless persisted?(saved, template)
        next saved
      end
    end

    def update(id, attributes)
      lock.synchronize(@account.id) do
        templates = all
        index = templates.index {|v| v['id'].to_s == id.to_s}
        raise Ginseng::NotFoundError, "テンプレート '#{id}' が見つかりません。" unless index
        template = normalize(attributes).merge('id' => id.to_s)
        templates[index] = template
        persist(templates)
        saved = find(id)
        raise Ginseng::GatewayError, 'テンプレートを保存できませんでした。' unless persisted?(saved, template)
        next saved
      end
    end

    def delete(id)
      lock.synchronize(@account.id) do
        templates = all
        target = templates.find {|v| v['id'].to_s == id.to_s}
        raise Ginseng::NotFoundError, "テンプレート '#{id}' が見つかりません。" unless target
        persist(templates.reject {|v| v['id'].to_s == id.to_s})
        raise Ginseng::GatewayError, 'テンプレートを削除できませんでした。' if find(id)
        next target
      end
    end

    private

    def lock
      return @lock ||= ComposeTemplateLockStorage.new
    end

    def user_config
      return @account.user_config
    end

    def normalize(attributes)
      attributes = attributes.transform_keys(&:to_s)
      cw = attributes['cw'].to_s
      return {
        'name' => attributes['name'].to_s,
        'body' => attributes['body'].to_s,
        'cw' => cw.empty? ? nil : cw,
      }
    end

    # nil の cw は保存時に deep_compact で除去されるため、read-back の照合はフィールド
    # 単位（アクセサ経由・欠落キーは nil を返し expected の nil と一致）で行う。
    # 空文字列の body は deep_compact で保持されるので照合を通る。
    def persisted?(saved, expected)
      return false unless saved
      return FIELDS.all? {|k| saved[k] == expected[k]}
    end

    def persist(templates)
      user_config.update(compose: {templates: templates})
    end
  end
end
