module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def handle_pre_toot(body, params = {})
      return body if ignore?(body)
      @tags.body = TagContainer.tweak(body['status'])
      temp_text = create_temp_text(body)
      TaggingDictionary.new.reverse_each do |k, v|
        next if k.length < @config['/tagging/word/minimum_length']
        next unless temp_text =~ v[:pattern]
        @tags.push(k)
        @tags.concat(v[:words])
        temp_text.gsub!(v[:pattern], '')
      end
      @tags.concat(create_attachment_tags(body))
      @tags.concat(TagContainer.default_tags)
      body['status'] = append(body['status'], @tags)
      @result.concat(@tags.create_tags)
      return body
    end

    private

    def ignore?(body)
      @config['/tagging/ignore_addresses'].each do |addr|
        return true if body['status'] =~ Regexp.new("(^|\s)#{addr}($|\s)")
      end
      return false unless body['visibility'].present?
      return false if body['visibility'] == 'public'
      return true
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
      rescue => e
        @logger.error(Ginseng::Error.create(e).to_h.merge(media_id: id))
      end
      return tags
    end

    def append(body, tags)
      return body unless tags.present?
      via = body.match(Regexp.new(@config['/twittodon/pattern']))
      body.sub!(via[0], '') if via.present?
      lines = body.each_line.map(&:chomp).to_a
      lines.clone.reverse_each do |line|
        break unless line =~ /^\s*(#[[:word:]]+\s*)$/
        line = lines.pop.strip
        tags.body = body = lines.join("\n")
        line.split(/\s+/).map{|v| tags.push(v)}
      end
      r = [body, tags.to_s]
      r.push(via[1]) if via.present?
      return r.join("\n")
    end
  end
end
