module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      @tags.body = body['status']
      tmp_body = @tags.body.clone
      TaggingDictionary.new.reverse_each do |k, v|
        next if k.length < @config['/tagging/word/minimum_length']
        next unless tmp_body =~ v[:pattern]
        @tags.push(k)
        @tags.concat(v[:words])
        tmp_body.gsub!(v[:pattern], '')
      end
      tags.concat(TagContainer.default_tags) if default_tags?(body)
      body['status'] = append(body['status'], @tags)
      @count += @tags.count
      return body
    end

    private

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
        tags.body = lines.join("\n")
        line.split(/\s/).map{|v| tags.push(v)}
      end
      return [tags.body, tags.to_s].join("\n")
    end
  end
end
