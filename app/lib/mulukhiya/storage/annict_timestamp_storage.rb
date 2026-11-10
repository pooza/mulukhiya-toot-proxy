module Mulukhiya
  class AnnictTimestampStorage < JSONStorage
    def default_value
      return {}
    end

    def prefix
      return 'annict'
    end
  end
end
