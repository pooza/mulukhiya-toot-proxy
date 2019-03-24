module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      container = TagContainer.new
      container.body = body['status']
      TaggingDictionary.new.each do |k, v|
        next if k.length < @config['/tagging/word/minimum_length']
        next unless body['status'] =~ v[:pattern]
        container.push(k)
        container.concat(v[:words])
      end
      tags = container.create_tags
      @count += tags.count
      body['status'] = [body['status'], tags.join(' ')].join("\n") if tags.present?
      return body
    end
  end
end
