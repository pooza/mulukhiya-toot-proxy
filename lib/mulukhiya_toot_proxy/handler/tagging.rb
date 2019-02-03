module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      tags = []
      words do |word|
        tag = Mastodon.create_tag(word.gsub(/[\s　]/, ''))
        next if body['status'].include?(tag)
        next unless body['status'] =~ Regexp.new(word.gsub(' ', '[\s　]?'))
        tags.push(tag)
        increment!
      end
      return unless tags.present?
      body['status'] = "#{body['status']}\n#{tags.join(' ')}"
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
