module Mulukhiya
  class FilterCommandContract < Contract
    params do
      required(:command).value(:string)
      optional(:phrase).value(:string)
      optional(:tag).value(:string)
      optional(:action).value(:string)
    end

    rule(:command) do
      key.failure('コマンドが正しくありません。') unless value == 'filter'
    end

    rule(:phrase, :tag) do
      if !values[:phrase].present? && !values[:tag].present?
        key.failure('phraseかtagのいずれかが必要です。')
      end
    end

    rule(:action) do
      unless [nil, 'register', 'unregister'].member?(value)
        key.failure('"register" または "unregister" で指定してください。')
      end
    end
  end
end
