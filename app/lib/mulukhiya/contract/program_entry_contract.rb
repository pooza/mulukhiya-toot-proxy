module Mulukhiya
  class ProgramEntryContract < Contract
    PARAMS_KEYS = [
      :key, :series, :minutes, :episode, :episode_suffix, :subtitle,
      :air, :livecure, :enable, :extra_tags,
      :annict_work_id, :annict_episode_id, :source_type, :source_url
    ].freeze
    MAX_KEY_SIZE = 64
    MAX_TEXT_SIZE = 200
    MAX_TAGS = 32
    MAX_TAG_SIZE = 64
    KEY_FORMAT = /\A[A-Za-z0-9_-]+\z/
    URL_FORMAT = %r{\Ahttps?://}

    params do
      optional(:key).value(:string, max_size?: MAX_KEY_SIZE)
      required(:series).value(:string, max_size?: MAX_TEXT_SIZE)
      optional(:minutes).maybe(:integer)
      optional(:episode).maybe(:integer)
      optional(:episode_suffix).maybe(:string, max_size?: MAX_TEXT_SIZE)
      optional(:subtitle).maybe(:string, max_size?: MAX_TEXT_SIZE)
      optional(:air).value(:bool)
      optional(:livecure).value(:bool)
      optional(:enable).value(:bool)
      optional(:extra_tags).maybe(:array, max_size?: MAX_TAGS)
      optional(:annict_work_id).maybe(:integer)
      optional(:annict_episode_id).maybe(:integer)
      # audit metadata: 書き込み専用。エディタが Annict 検索結果を選択した際に
      # source_type='annict' を自動設定して保存する。読み出し箇所はないが、
      # 後追いで「どの経路で記録されたか」を辿るため保持している
      optional(:source_type).maybe(:string, max_size?: MAX_TEXT_SIZE)
      optional(:source_url).maybe(:string, max_size?: MAX_TEXT_SIZE)
    end

    rule(:key) do
      next if value.to_s.empty?
      key.failure('英数字・アンダースコア・ハイフンのみ使用できます。') unless KEY_FORMAT.match?(value)
    end

    rule(:series) do
      key.failure('空欄です。') if value.to_s.empty?
    end

    rule(:extra_tags) do
      next unless value.is_a?(Array)
      unless value.all? {|s| s.is_a?(String) && s.size <= MAX_TAG_SIZE}
        key.failure("文字列 (各要素 #{MAX_TAG_SIZE} 文字以下) の配列で指定してください。")
      end
    end

    rule(:source_url) do
      next unless value.is_a?(String)
      key.failure('http(s):// で始まる URL を指定してください。') unless URL_FORMAT.match?(value)
    end
  end
end
