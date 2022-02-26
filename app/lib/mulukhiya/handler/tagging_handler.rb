module Mulukhiya
  class TaggingHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      lines = status_lines.clone
      lines.clone.reverse_each do |line|
        break unless tags_line?(line)
        tags.merge(lines.pop.strip.split(/\s+/))
      end
      tags.text = lines.join("\n")
      lines.push(tags.create_tags.join(' '))
      parser.text = payload[text_field] = lines.join("\n")
    end

    private

    def tags_line?(line)
      return /^\s*(#[[:word:]]+\s*)+$/.match?(line)
    end
  end
end
