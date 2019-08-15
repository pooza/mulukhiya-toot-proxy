module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def handle_pre_toot(body, params = {})
      return body if ignore?(body)
      @tags.body = TagContainer.tweak(body['status'])
      via = body['status'].match(Regexp.new(@config['/twittodon/pattern']))
      temp_text = create_temp_text(body)
      TaggingDictionary.new.reverse_each do |k, v|
        next if k.length < @config['/tagging/word/minimum_length']
        next unless temp_text =~ v[:pattern]
        @tags.push(k)
        @tags.concat(v[:words])
        temp_text.gsub!(v[:pattern], '')
      end
      @tags.concat(create_attachment_tags(body)) if attachment_tags?(body)
      @tags.concat(TagContainer.default_tags) if default_tags?(body)
      body['status'] = append(body['status'], @tags, via)
      @result.concat(@tags.create_tags)
      return body
    end

    private

    def ignore?(body)
      return true if body['visibility'] == 'direct'
      @config['/tagging/ignore_addresses'].each do |addr|
        return true if body['status'] =~ Regexp.new("(^|\s)#{addr}($|\s)")
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
      text = [@tags.body.gsub(Regexp.new(@config['/mastodon/account/pattern']), '')]
      text.concat(body['poll']['options']) if body['poll']
      return text.join('///')
    end

    def create_attachment_tags(body)
      tags = []
      (body['media_ids'] || []).each do |id|
        type = Mastodon.lookup_attachment(id)['file_content_type']
        ['video', 'image', 'audio'].each do |mediatype|
          if type.start_with?("#{mediatype}/")
            tags.push(@config["/tagging/attachment_tags/#{mediatype}"])
            break
          end
        end
      rescue Ginseng::ConfigError
        next
      rescue => e
        @logger.error(Ginseng::Error.create(e).to_h.merge(media_id: id))
        next
      end
      return tags
    end

    def append(body, tags, via)
      return body unless tags.present?
      body.sub!(via[0], '') if via.present?
      lines = body.each_line.map(&:chomp).to_a
      if lines.last&.match?(Regexp.new("^(#[[:word:]]+\s*)+$", Regexp::IGNORECASE))
        line = lines.pop
        body = lines.join("\n")
        tags.body = body
        line.split(/\s+/).map{|v| tags.push(v)}
      end
      r = [body, tags.to_s]
      r.push(via[1]) if via.present?
      return r.join("\n")
    end
  end
end
