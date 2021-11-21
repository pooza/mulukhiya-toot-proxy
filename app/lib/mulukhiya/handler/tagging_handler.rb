module Mulukhiya
  class TaggingHandler < Handler
    def handle_pre_toot(payload, params = {})
      self.payload = payload
      lines = @status.each_line(chomp: true).to_a
      last = lines.pop if Ginseng::URI.parse(lines.last.to_s).absolute?
      lines.clone.reverse_each do |line|
        break unless /^\s*(#[[:word:]]+\s*)+$/.match?(line)
        tags.merge(lines.pop.strip.split(/\s+/))
      end
      tags.text = lines.join("\n")
      lines.push(tags.create_tags.join(' '))
      lines.push(last) if last
      parser.text = payload[text_field] = lines.join("\n")
    end
  end
end
