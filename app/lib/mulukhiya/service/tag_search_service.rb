module Mulukhiya
  class TagSearchService
    include Package

    def initialize(dictionary = TaggingDictionary.new)
      @dictionary = dictionary
    end

    def search(query)
      results = {}
      @dictionary.cache.each do |word, entry|
        next unless query.match?(entry[:regexp])
        entry[:word] = word
        entry[:short] = @dictionary.short?(word)
        entry[:words].unshift(word)
        entry[:tags] = TagContainer.new(entry[:words]).create_tags
        results[word] = entry
      rescue => e
        e.log(word:, entry:)
      end
      return results
    end
  end
end
