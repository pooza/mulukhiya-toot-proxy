module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      tags = []
      words do |word|
        tag = Mastodon.create_tag(word.gsub(/[\s　]/, ''))
        next if body['status'].include?(tag)
        if word.include?(' ')
          next unless body['status'] =~ Regexp.new(word.gsub(' ', '[\s　]?'))
        else
          next unless body['status'].include?(word)
        end
        tags.push(tag)
        increment!
      end
      body['status'] = "#{body['status']}\n#{tags.join(' ')}" if tags.present?
      return body
    end

    def words
      return enum_for(__method__) unless block_given?
      HTTParty.get(@config['/tagging/dictionary/url']).parsed_response.each do |entry|
        @config['/tagging/dictionary/fields'].each do |field|
          yield entry[field] if entry[field].present?
        end
      rescue
        next
      end
    end
  end
end
