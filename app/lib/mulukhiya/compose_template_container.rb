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
      synchronize do
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
      synchronize do
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
      synchronize do
        templates = all
        target = templates.find {|v| v['id'].to_s == id.to_s}
        raise Ginseng::NotFoundError, "テンプレート '#{id}' が見つかりません。" unless target
        persist(templates.reject {|v| v['id'].to_s == id.to_s})
        raise Ginseng::GatewayError, 'テンプレートを削除できませんでした。' if find(id)
        next target
      end
    end

    private

    # ロックを取り、その内側で user_config を読み直してから block を実行する。
    # @account.user_config はメモ化された UserConfig（構築時点の値のスナップショット）
    # を返すため、ロック取得前に誰かがそれを参照していると、古い値の上で
    # read-modify-write することになり lost update が黙って復活する。ロック内で
    # fresh read を強制して構造的に防ぐ (#4461)。
    def synchronize
      lock.synchronize(@account.id) do
        @user_config = UserConfig.new(@account)
        next yield
      end
    end

    def lock
      return @lock ||= ComposeTemplateLockStorage.new
    end

    def user_config
      return @user_config ||= @account.user_config
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

    # UserConfig#update は書き込み失敗を自前で alert して握りつぶすため、read-back
    # 由来の GatewayError と合わせると Redis の一過性障害 1 回で alert が 2 発飛ぶ。
    # ここは alert しない update! を使い、GatewayError に包み直して通知を controller
    # の 1 本にまとめる。
    #
    # メッセージには例外クラス名を混ぜない（read-back 失敗時と同じ文言に揃え、
    # 内部実装をクライアントへ出さない）。根因は Exception#cause として Sentry に
    # 残るので、切り分けはそちらで行う (#4461)。
    def persist(templates)
      user_config.update!(compose: {templates: templates})
    rescue
      raise Ginseng::GatewayError, 'テンプレートを保存できませんでした。'
    end
  end
end
