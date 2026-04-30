module Mulukhiya
  class ProgramEntryContract < Contract
    PARAMS_KEYS = [
      :key, :series, :minutes, :episode, :episode_suffix, :subtitle,
      :air, :livecure, :enable, :extra_tags,
      :annict_work_id, :annict_episode_id, :source_type, :source_url
    ].freeze

    params do
      optional(:key).value(:string)
      required(:series).value(:string)
      optional(:minutes).maybe(:integer)
      optional(:episode).maybe(:integer)
      optional(:episode_suffix).maybe(:string)
      optional(:subtitle).maybe(:string)
      optional(:air).value(:bool)
      optional(:livecure).value(:bool)
      optional(:enable).value(:bool)
      optional(:extra_tags).maybe(:array)
      optional(:annict_work_id).maybe(:integer)
      optional(:annict_episode_id).maybe(:integer)
      optional(:source_type).maybe(:string)
      optional(:source_url).maybe(:string)
    end

    rule(:series) do
      key.failure('空欄です。') if value.to_s.empty?
    end

    rule(:extra_tags) do
      next unless value.is_a?(Array)
      key.failure('文字列の配列で指定してください。') unless value.all?(String)
    end
  end
end
