module Mulukhiya
  class ProgramEntryUpdateContract < Contract
    params do
      optional(:key).value(:string)
      optional(:series).maybe(:string, max_size?: ProgramEntryContract::MAX_TEXT_SIZE)
      optional(:minutes).maybe(:integer)
      optional(:episode).maybe(:integer)
      optional(:episode_suffix).maybe(:string, max_size?: ProgramEntryContract::MAX_TEXT_SIZE)
      optional(:subtitle).maybe(:string, max_size?: ProgramEntryContract::MAX_TEXT_SIZE)
      optional(:air).value(:bool)
      optional(:livecure).value(:bool)
      optional(:enable).value(:bool)
      optional(:extra_tags).maybe(:array, max_size?: ProgramEntryContract::MAX_TAGS)
      optional(:annict_work_id).maybe(:integer)
      optional(:annict_episode_id).maybe(:integer)
      optional(:source_type).maybe(:string, max_size?: ProgramEntryContract::MAX_TEXT_SIZE)
      optional(:source_url).maybe(:string, max_size?: ProgramEntryContract::MAX_TEXT_SIZE)
    end

    rule(:series) do
      next unless key?
      key.failure('空欄です。') if value.to_s.empty?
    end

    rule(:extra_tags) do
      next unless value.is_a?(Array)
      unless value.all? {|s| s.is_a?(String) && s.size <= ProgramEntryContract::MAX_TAG_SIZE}
        key.failure("文字列 (各要素 #{ProgramEntryContract::MAX_TAG_SIZE} 文字以下) の配列で指定してください。")
      end
    end
  end
end
