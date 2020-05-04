module Mulukhiya
  class TaggingHandler < Handler
    def handle_pre_toot(body, params = {})
      @status = TagContainer.tweak(body[status_field] || '')
      return body unless executable?(body)
      tags.text = @status
      @dic = TaggingDictionary.new
      tags.concat(@dic.matches(body))
      tags.concat(create_attachment_tags(body))
      tags.concat(@sns.account.tags)
      body[status_field] = append
      @result.concat(tags.create_tags)
      return body
    end

    private

    def executable?(body)
      parser.accts do |acct|
        return false if acct.agent?
      end
      return true unless body['visibility'].present?
      return true if body['visibility'] == 'public'
      return false
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
        errors.push(class: e.class.to_s, message: e.message, media_id: id)
      end
      return tags.uniq
    end

    def append
      body = @status
      return body unless tags.present?
      via = body.match(@config['/twittodon/pattern'])
      body.sub!(via[0], '') if via.present?
      lines = body.each_line.map(&:chomp).to_a
      lines.clone.reverse_each do |line|
        break unless /^\s*(#[[:word:]]+\s*)+$/.match?(line)
        line = lines.pop.strip
        tags.text = body = lines.join("\n")
        tags.concat(line.split(/\s+/))
      end
      body = [body, tags.to_s]
      body.push(via[1]) if via.present?
      return body.join("\n")
    end
  end
end
