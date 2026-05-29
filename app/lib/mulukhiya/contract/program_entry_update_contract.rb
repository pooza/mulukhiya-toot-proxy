module Mulukhiya
  class ProgramEntryUpdateContract < Contract
    params do
      optional(:key).value(:string)
      optional(:series).maybe(:string, max_size?: ProgramEntryContract::MAX_TEXT_SIZE)
      optional(:minutes).maybe(:integer)
      optional(:start_time).maybe(:string, max_size?: ProgramEntryContract::MAX_TEXT_SIZE)
      optional(:episode).maybe(:integer)
      optional(:episode_suffix).maybe(:string, max_size?: ProgramEntryContract::MAX_TEXT_SIZE)
      optional(:subtitle).maybe(:string, max_size?: ProgramEntryContract::MAX_TEXT_SIZE)
      optional(:air).value(:bool)
      optional(:livecure).value(:bool)
      optional(:enable).value(:bool)
      optional(:extra_tags).maybe(:array, max_size?: ProgramEntryContract::MAX_TAGS)
      optional(:annict_work_id).maybe(:integer)
      optional(:annict_episode_id).maybe(:integer)
      # audit metadata: ProgramEntryContract と同様、書き込み専用で保持する
      optional(:source_type).maybe(:string, max_size?: ProgramEntryContract::MAX_TEXT_SIZE)
      optional(:source_url).maybe(:string, max_size?: ProgramEntryContract::MAX_TEXT_SIZE)
    end

    rule(:series) do
      next unless key?
      key.failure('シリーズ名が空欄です。') if value.to_s.empty?
    end

    rule(:extra_tags) do
      next unless value.is_a?(Array)
      unless value.all? {|s| s.is_a?(String) && s.size <= ProgramEntryContract::MAX_TAG_SIZE}
        key.failure("追加タグは文字列 (各要素 #{ProgramEntryContract::MAX_TAG_SIZE} 文字以下) の配列で指定してください。")
      end
    end

    rule(:source_url) do
      next unless value.is_a?(String)
      unless ProgramEntryContract::URL_FORMAT.match?(value)
        key.failure('ソース URL は http(s):// で始まる URL を指定してください。')
      end
    end

    rule(:start_time) do
      next unless value.is_a?(String)
      next if value.empty?
      unless ProgramEntryContract::TIME_FORMAT.match?(value)
        key.failure('開始時刻は HH:MM 形式 (例 21:00) で指定してください。')
      end
    end
  end
end
