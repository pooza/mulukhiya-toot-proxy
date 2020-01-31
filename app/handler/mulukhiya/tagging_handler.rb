module Mulukhiya
  class TaggingHandler < Handler
    def handle_pre_toot(body, params = {})
      @status = body[status_field].to_s
      return body if ignore?(body)
      @results.tags.body = TagContainer.tweak(@status)
      temp_text = create_temp_text(body)
      TaggingDictionary.new.reverse_each do |k, v|
        next if k.length < @config['/tagging/word/minimum_length']
        next unless temp_text.match?(v[:pattern])
        @results.tags.push(k)
        @results.tags.concat(v[:words])
        temp_text.gsub!(v[:pattern], '')
      end
      @results.tags.concat(create_attachment_tags(body))
      @results.tags.concat(TagContainer.default_tags)
      @results.tags.concat(@sns.account.tags)
      body[status_field] = append(@status, @results.tags)
      @result.concat(@results.tags.create_tags)
      return body
    end

    private

    def ignore?(body)
      return true unless @status.present?
      parser.accts do |acct|
        return true if acct.agent?
      end
      return false unless body['visibility'].present?
      return false if body['visibility'] == 'public'
      return true
    end

    def create_temp_text(body)
      return '' unless @results.tags.body&.present?
      text = [@results.tags.body.gsub(Acct.pattern, '')]
      text.concat(body['poll']['options']) if body['poll']
      return text.join('///')
    end

    def create_attachment_tags(body)
      tags = []
      (body[attachment_key] || []).each do |id|
        type = Environment.attachment_class[id].file_content_type
        ['video', 'image', 'audio'].each do |mediatype|
          next unless type.start_with?("#{mediatype}/")
          tags.push(@config["/tagging/attachment_tags/#{mediatype}"])
        end
      rescue => e
        @logger.error(Ginseng::Error.create(e).to_h.merge(media_id: id))
      end
      return tags.uniq
    end

    def append(body, tags)
      return body unless tags.present?
      via = body.match(Regexp.new(@config['/twittodon/pattern']))
      body.sub!(via[0], '') if via.present?
      lines = body.each_line.map(&:chomp).to_a
      lines.clone.reverse_each do |line|
        break unless /^\s*(#[[:word:]]+\s*)+$/.match?(line)
        line = lines.pop.strip
        tags.body = body = lines.join("\n")
        tags.concat(line.split(/\s+/))
      end
      r = [body, tags.to_s]
      r.push(via[1]) if via.present?
      return r.join("\n")
    end
  end
end
