require 'unicode'

module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      container = TagContainer.new
      container.body = body['status']
      tmp_body = Unicode::nfkc(body['status'])
      TaggingDictionary.new.reverse_each do |k, v|
        next if k.length < @config['/tagging/word/minimum_length']
        next unless tmp_body =~ v[:pattern]
        container.push(k)
        container.concat(v[:words])
        tmp_body.gsub!(v[:pattern], '')
      end
      tags = container.create_tags
      @count += tags.count
      body['status'] = [body['status'], tags.join(' ')].join("\n") if tags.present?
      return body
    end
  end
end
