module Mulukhiya
  class TaggingHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return unless executable?
      tags.text = @status
      tags.merge(TaggingDictionary.new.matches(payload)) if @status
      parser.text = payload[text_field] = update_status
      result.push(tags: tags.create_tags)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, status: @status)
    end

    private

    def executable?
      return false if parser.command?
      return false if parser.accts.any?(&:agent?)
      return true if payload[visibility_field].empty?
      return true if payload[visibility_field] == controller_class.visibility_name(:public)
      return false
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
