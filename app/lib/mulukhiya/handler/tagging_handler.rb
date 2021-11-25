module Mulukhiya
  class TaggingHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      lines = status_lines.clone
      last = lines.pop if end_with_uri?(lines)
      lines.clone.reverse_each do |line|
        break unless tags_line?(line)
        tags.merge(lines.pop.strip.split(/\s+/))
      end
      tags.text = lines.join("\n")
      lines.push(tags.create_tags.join(' '))
      lines.push(last) if last
      parser.text = payload[text_field] = lines.join("\n")
    end

    private

    def tags_line?(line)
      return /^\s*(#[[:word:]]+\s*)+$/.match?(line)
    end

    def end_with_uri?(lines)
      return false unless lines.present?
      return false unless uri = Ginseng::URI.parse(lines.last)
      return false unless uri.absolute?
      return false unless uri.scheme.match?(/^https?$/)
      return true
    rescue Addressable::URI::InvalidURIError
      return false
    end
  end
end
