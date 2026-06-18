module Mulukhiya
  class NowplayingResolveUrlContract < Contract
    MAX_URL_SIZE = 2048
    URL_FORMAT = %r{\Ahttps?://}

    params do
      required(:url).filled(:string, max_size?: MAX_URL_SIZE)
    end

    rule(:url) do
      key.failure('URL は http(s):// で始まる URL を指定してください。') unless URL_FORMAT.match?(value.to_s)
    end
  end
end
