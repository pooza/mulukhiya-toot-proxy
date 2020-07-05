module Mulukhiya
  class TaggingHandler < Handler
    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body unless executable?(body)
      tags.text = @status
      tags.concat(TaggingDictionary.new.matches(body))
      tags.concat(create_attachment_tags(body))
      tags.concat(@sns.account.tags)
      body[status_field] = update_status
      result.push(tags: tags.create_tags)
      return body
    end

    private

    def executable?(body)
      return false if parser.accts.any?(&:agent?)
      return true unless body['visibility'].present?
      return true if body['visibility'] == 'public'
      return false
    end

    def create_attachment_tags(body)
      tags = []
      (body[attachment_key] || []).each do |id|
        type = Environment.attachment_class[id].type
        ['video', 'image', 'audio'].each do |mediatype|
          next unless type.start_with?("#{mediatype}/")
          tags.push(@config["/tagging/attachment_tags/#{mediatype}"])
        rescue Ginseng::ConfigError => e
          result.push(info: e.message)
        end
      rescue => e
        errors.push(class: e.class.to_s, message: e.message, media_id: id)
      end
      return tags.uniq
    end

    def update_status
      return @status unless tags.present?
      via = @status.match(@config['/twittodon/pattern'])
      @status.sub!(via[0], '') if via.present?
      lines = @status.each_line(chomp: true).to_a
      lines.clone.reverse_each do |line|
        break unless /^\s*(#[[:word:]]+\s*)+$/.match?(line)
        line = lines.pop.strip
        tags.text = lines.join("\n")
        tags.concat(line.split(/\s+/))
      end
      lines.push(tags.to_s)
      lines.push(via[1]) if via.present?
      return @status = lines.join("\n")
    end
  end
end
