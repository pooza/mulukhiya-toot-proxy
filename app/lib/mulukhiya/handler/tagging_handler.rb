module Mulukhiya
  class TaggingHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return unless executable?
      tags.text = @status
      tags.merge(TaggingDictionary.new.matches(payload)) if @status
      tags.merge(media_tags) if TagContainer.media_tag?
      tags.account = @sns.account
      parser.text = payload[text_field] = update_status
      result.push(tags: tags.create_tags)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, status: @status)
    end

    private

    def executable?
      return false if parser.command?
      return false if parser.accts.any?(&:agent?)
      return true if payload['visibility'].empty?
      return true if payload['visibility'] == 'public'
      return false
    end

    def media_tags
      tags = Set[]
      (payload[attachment_field] || []).each do |id|
        type = attachment_class[id].type
        ['video', 'image', 'audio'].freeze.each do |mediatype|
          next unless type.start_with?("#{mediatype}/")
          tags.add(config["/tagging/media/tags/#{mediatype}"])
        rescue Ginseng::ConfigError => e
          result.push(info: e.message)
        end
      rescue => e
        errors.push(class: e.class.to_s, message: e.message, attachment_id: id)
      end
      return tags
    end

    def update_status
      return @status if tags.empty?
      via = @status.match(config['/twittodon/pattern'])
      @status.sub!(via[0], '') if via.present?
      lines = @status.each_line(chomp: true).to_a
      lines.clone.reverse_each do |line|
        break unless /^\s*(#[[:word:]]+\s*)+$/.match?(line)
        line = lines.pop.strip
        tags.text = lines.join("\n")
        tags.merge(line.split(/\s+/))
      end
      lines.push(tags.to_s)
      lines.push(via[1]) if via.present?
      return lines.join("\n")
    end
  end
end
