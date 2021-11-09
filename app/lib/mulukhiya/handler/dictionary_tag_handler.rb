module Mulukhiya
  class DictionaryTagHandler < TagHandler
    def disable?
      return true unless RemoteDictionary.all.present?
      return super
    end

    def addition_tags
      return TaggingDictionary.new.matches(flatten_payload)
    end

    def schema # rubocop:disable Metrics/MethodLength
      return super.deep_merge(
        type: 'object',
        properties: {
          dics: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                url: {type: 'string', format: 'uri'},
                name: {type: 'string'},
                type: {type: 'string'},
                edit: {
                  type: 'object',
                  properties: {'url' => {type: 'string', format: 'uri'}},
                },
              },
            },
          },
          word: {
            type: 'object',
            properties: {
              min: {type: 'integer'},
              min_kanji: {type: 'integer'},
              without_kanji_pattern: {type: 'string'},
            },
          },
        },
        required: ['dics'],
      )
    end
  end
end
