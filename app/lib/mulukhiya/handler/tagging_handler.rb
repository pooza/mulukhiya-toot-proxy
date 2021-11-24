module Mulukhiya
  class TaggingHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      lines = @status.each_line(chomp: true).to_a
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

    def tags_line?(line)
      return /^\s*(#[[:word:]]+\s*)+$/.match?(line)
    end

    def end_with_uri?(lines)
      return false unless lines.present?
      uri = Ginseng::URI.parse(lines.last)
      return false unless uri.absolute?
      return false unless uri.scheme.match?(/^https?$/)
      return true
    end
  end
end
