module Mulukhiya
  class TaggingHandler < Handler
    def disable?
      return false
    end

    def handle_pre_toot(payload, params = {})
      self.payload = payload
      lines = status_lines.clone
      lines.clone.reverse_each do |line|
        break unless tags_line?(line)
        tags.merge(lines.pop.strip.split(/[[:blank:]]+/))
      end
      tags.text = lines.join("\n")
      lines.push('') if tags.text.present? && lines.last.present? # 1行アキはMastodon 4.2対応
      lines.push(tags.create_tags.join(' '))
      parser.text = payload[text_field] = lines.join("\n")
    end

    def self.normalize_rules
      return new.handler_config(:normalize, :rules) || []
    end

    private

    def tags_line?(line)
      return /^[[:blank:]]*(#[[:word:]]+[[:blank:]]*)+$/.match?(line)
    end
  end
end
