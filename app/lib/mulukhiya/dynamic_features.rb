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
    }.freeze

    def initialize(sns)
      @sns = sns
    end

    def to_h
      return REGISTRY.transform_values {|resolver| resolver.call(@sns)}
    end
  end
end
