module Mulukhiya
  class SlackWebhookPayload < WebhookPayload
    def errors
      @errors ||= SlackWebhookContract.new.exec(raw) if raw
      return @errors
    end

    def blocks?
      return blocks.is_a?(Array)
    end

    def attachments?
      return attachments.is_a?(Array)
    end

    def header
      return raw['spoiler_text'] unless blocks?
      return blocks.find {|v| v['type'] == 'header'}.dig('text', 'text')
    rescue => e
      e.log(payload: raw)
      return nil
    end

    alias spoiler_text header

    def text
      parts = []
      parts.push(blocks? ? extract_blocks_text : parse_legacy_text(raw['text']))
      parts.concat(attachment_texts) if attachments?
      return parts.compact.reject(&:empty?).join("\n\n")
    rescue => e
      e.log(payload: raw)
      return nil
    end

    def images
      unless @images
        @images = []
        @images.concat(blocks.select {|v| v['type'] == 'image'}) if blocks?
        collect_attachment_images
      end
      return @images
    rescue => e
      e.log(payload: raw)
      return []
    end

    def image_uris
      return images.filter_map {|v| Ginseng::URI.parse(v['image_url'])}
    rescue => e
      e.log(payload: raw)
      return []
    end

    def values
      values = {status_field => text}
      values[spoiler_field] = header if header
      values['attachments'] = images
      return values
    end

    alias to_h values

    private

    def extract_blocks_text
      parts = []
      (blocks || []).each do |block|
        case block['type']
        when 'section'
          parts.push(block.dig('text', 'text'))
        when 'context'
          elements = block['elements'] || []
          parts.concat(elements.filter_map {|e| e['text']})
        when 'rich_text'
          parts.concat(extract_rich_text(block))
        end
      end
      return parts.compact.reject(&:empty?).join("\n")
    end

    def extract_rich_text(block)
      parts = []
      (block['elements'] || []).each do |section|
        texts = (section['elements'] || []).filter_map {|e| e['text']}
        parts.push(texts.join) unless texts.empty?
      end
      return parts
    end

    def attachment_texts
      return [] unless attachments?
      attachments.filter_map {|a| format_attachment(a)}
    end

    def format_attachment(attachment)
      parts = []
      parts.push(attachment['pretext']) if attachment['pretext'].present?
      parts.push(format_linked_text(attachment, 'author_name', 'author_link'))
      parts.push(format_linked_text(attachment, 'title', 'title_link'))
      parts.push(attachment['text']) if attachment['text'].present?
      parts.concat(format_fields(attachment['fields']))
      parts.push(attachment['footer']) if attachment['footer'].present?
      parts.compact!
      return nil if parts.empty?
      return parts.join("\n")
    end

    def format_linked_text(hash, text_key, link_key)
      return nil unless hash[text_key].present?
      return hash[link_key].present? ? "[#{hash[text_key]}](#{hash[link_key]})" : hash[text_key]
    end

    def format_fields(fields)
      return [] unless fields.is_a?(Array)
      return fields.filter_map {|f| "**#{f['title']}**: #{f['value']}" if f['title'].present?}
    end

    def collect_attachment_images
      return unless attachments?
      attachments.each do |a|
        @images.push('image_url' => a['image_url']) if a['image_url'].present?
        @images.push('image_url' => a['thumb_url']) if a['thumb_url'].present?
      end
    end

    def parse_legacy_text(text)
      return text if text.nil?
      temp = text.dup
      temp = temp.gsub(':bell:', "\u{1F514}")
      text.to_s.scan(/(<(.*?)\|(.*?)>)/).each do |matches|
        pair, link, label = matches
        temp = temp.gsub(pair, "[ #{label} ](#{link})")
      end
      return temp
    rescue => e
      e.log(text:)
      return text
    end
  end
end
