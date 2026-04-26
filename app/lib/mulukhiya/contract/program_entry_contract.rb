module Mulukhiya
  class ProgramEntryContract < Contract
    params do
      optional(:key).value(:string)
      required(:series).value(:string)
      optional(:minutes).value(:integer)
      optional(:episode).value(:integer)
      optional(:episode_suffix).value(:string)
      optional(:subtitle).value(:string)
      optional(:air).value(:bool)
      optional(:livecure).value(:bool)
      optional(:enable).value(:bool)
      optional(:extra_tags).array(:string)
      optional(:annict_work_id).value(:integer)
      optional(:annict_episode_id).value(:integer)
      optional(:source_type).value(:string)
      optional(:source_url).value(:string)
    end

    rule(:series) do
      key.failure('空欄です。') if value.to_s.empty?
    end
  end
end
