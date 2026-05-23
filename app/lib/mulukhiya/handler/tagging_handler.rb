module Mulukhiya
  class TaggingHandler < Handler
    def disable?
      return false
    end

    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return if non_federated_payload?
      return rebuild_status_with_tags
    end

    def self.normalize_rules
      return new.handler_config(:normalize, :rules) || []
    end

    private

    def rebuild_status_with_tags
      lines = status_lines.clone
      lines.clone.reverse_each do |line|
        break unless tags_line?(line)
        tags.merge(lines.pop.strip.split(/[[:blank:]]+/))
      end
      tags.text = lines.join("\n")
      lines.push('') if tags.text.present? && lines.last.present? # 1行アキはMastodon 4.2対応
      lines.push(tags.create_tags.join(' '))
      text = lines.join("\n")
      parser.text = payload[text_field] = text
      return text
    end

    def tags_line?(line)
      return /^[[:blank:]]*(#[[:word:]]+[[:blank:]]*)+$/.match?(line)
    end
  end
end
