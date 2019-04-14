module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      return body if ignore?(body['status'])
      @tags.body = body['status']
      tmp_text = [@tags.body.clone]
      tmp_text.concat(body['poll']['options']) if body['poll']
      tmp_text = tmp_text.join('///')
      TaggingDictionary.new.reverse_each do |k, v|
        next if k.length < @config['/tagging/word/minimum_length']
        next unless tmp_text =~ v[:pattern]
        @tags.push(k)
        @tags.concat(v[:words])
        tmp_text.gsub!(v[:pattern], '')
      end
      tags.concat(TagContainer.default_tags) if default_tags?(body)
      body['status'] = append(body['status'], @tags)
      @result.concat(@tags.create_tags)
      return body
    end

    private

    def ignore?(body)
      @config['/tagging/ignore_addresses'].each do |addr|
        return true if body =~ Regexp.new("(^|\s)#{addr}($|\s)")
      end
      return false
    end

    def default_tags?(body)
      return true unless body['visibility']
      return true if body['visibility'] == 'public'
      return true if @config['/tagging/always_default_tags']
      return false
    end

    def append(body, tags)
      return body unless tags.present?
      lines = body.each_line.map(&:chomp).to_a
      if lines.last&.match?(Regexp.new("^(#[[:word:]]+\s*)+$", Regexp::IGNORECASE))
        line = lines.pop
        body = lines.join("\n")
        tags.body = body
        line.split(/\s/).map{|v| tags.push(v)}
      end
      return [body, tags.to_s].join("\n")
    end
  end
end
