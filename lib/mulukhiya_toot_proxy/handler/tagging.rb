module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      return body if ignore?(body['status'])
      @tags.body = body['status']
      tmp_text = create_temp_text(body)
      TaggingDictionary.new.reverse_each do |k, v|
        next if k.length < @config['/tagging/word/minimum_length']
        next unless tmp_text =~ v[:pattern]
        @tags.push(k)
        @tags.concat(v[:words])
        tmp_text.gsub!(v[:pattern], '')
      end
      @tags.concat(TagContainer.default_tags) if default_tags?(body)
      @tags.concat(create_attachment_tags(body)) if attachment_tags?(body)
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

    def attachment_tags?(body)
      return body['media_ids'].present?
    end

    def create_temp_text(body)
      return '' unless @tags.body&.present?
      text = [@tags.body.clone]
      text.concat(body['poll']['options']) if body['poll']
      return text.join('///')
    end

    def create_attachment_tags(body)
      tags = []
      (body['media_ids'] || []).each do |id|
        type = Mastodon.lookup_attachment(id)['file_content_type']
        ['video', 'image'].each do |mediatype|
          if type.start_with?("#{mediatype}/")
            tags.push(@config["/tagging/attachment_tags/#{mediatype}"])
            break
          end
        end
      rescue Ginseng::ConfigError
        next
      rescue => e
        @logger.error(e)
        next
      end
      return tags
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
