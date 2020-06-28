module Mulukhiya
  class FilterCommandContract < Contract
    json do
      required(:command).value(:string)
      optional(:phrase).value(:string)
      optional(:tag).value(:string)
      optional(:action).value(:string)
    end

    rule(:command) do
      key.failure('コマンドが正しくありません。') unless value == 'filter'
    end

    rule(:phrase, :tag) do
      key.failure('phraseかtagのいずれかが必要です。') if !values[:phrase].present? && !values[:tag].present?
    end

    rule(:action) do
      unless [nil, 'register', 'unregister'].member?(value)
        key.failure('"register" または "unregister" で指定してください。')
      end
    end
  end
end
