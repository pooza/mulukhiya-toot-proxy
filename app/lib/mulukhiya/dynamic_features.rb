module Mulukhiya
  # /about レスポンスの features に動的合流させる機能フラグの登録簿 (#4348)。
  #
  # サーバーレベルの静的 features (`/{controller}/features/*` の sub_hash) に対し、
  # 以下の実行時状態を合流させる:
  #   - annict_linked    : リクエストの SNS アカウント単位の Annict 連携状態 (#4338)
  #   - media_catalog    : /{controller}/data 配下の機能フラグ。discovery を features
  #                        に一本化するため合流 (#4343)
  #   - program_editable : 番組表エディタ (livecure かつ auto_update 無効) で書き込み
  #                        API が利用可能か。WebUI の UI 出し分けに使う (#4272)
  #   - word_suggest     : 読み付き単語サジェスト (#4397)。word_suggest/urls が設定
  #                        されているか。capsicum の UI 出し分けに使う。フラグの正本を
  #                        URL 設定の有無に一本化し二重管理を避ける
  #   - nowplaying_resolver : ナウプレ enrich (#4382)。メタデータ → 共有 URL 解決
  #                        エンドポイントの可否。capsicum が enrich を試みるか判定に使う
  #
  # 新しい動的フラグ (例: spotify_linked) を増やす際は REGISTRY に 1 行追加する。
  class DynamicFeatures
    include Package

    REGISTRY = {
      'annict_linked' => ->(sns) {sns.account&.annict_linked? || false},
      'media_catalog' => ->(_sns) {Environment.controller_class.media_catalog?},
      'program_editable' => lambda {|_sns|
        Environment.controller_class.livecure? && !Program.instance.auto_update?
      },
      'word_suggest' => ->(_sns) {PronunciationDictionary.new.enabled?},
      'nowplaying_resolver' => ->(_sns) {NowplayingResolver.enabled?},
    }.freeze

    def initialize(sns)
      @sns = sns
    end

    def to_h
      return REGISTRY.transform_values {|resolver| resolver.call(@sns)}
    end
  end
end
