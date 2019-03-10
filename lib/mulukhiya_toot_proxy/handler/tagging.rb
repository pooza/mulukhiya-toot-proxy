module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      container = TagContainer.new
      container.body = body['status']
      TaggingDictionary.instance.each do |key, pattern|
        next if key.length < @config['/tagging/word/minimum_length']
        next unless body['status'] =~ pattern
        container.push(key)
      end
      tags = container.create_tags
      @count += tags.count
      body['status'] = [body['status'], tags.join(' ')].join("\n") if tags.present?
      return body
    end
  end
end
