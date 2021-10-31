module Mulukhiya
  class DictionaryTagHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      tags.text = @status
      tags.merge(dictionary_tags)
      result.push(tags: dictionary_tags)
    end

    private

    def dictionary_tags
      return TaggingDictionary.new.matches(payload)
    end
  end
end
