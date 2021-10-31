module Mulukhiya
  class TaggingHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      lines = @status.each_line(chomp: true).to_a
      lines.clone.reverse_each do |line|
        break unless /^\s*(#[[:word:]]+\s*)+$/.match?(line)
        tags.merge(lines.pop.strip.split(/\s+/))
      end
      tags.text = lines.join("\n")
      lines.push(tags.create_tags.join(' '))
      parser.text = payload[text_field] = lines.join("\n")
    end
  end
end
