module Mulukhiya
  class AttachmentReusingHandler < Handler
    def handle_pre_toot(body, params = {})
      return body unless body[attachment_field]
      ids = []
      body[attachment_field].each do |id|
        next unless src = attachment_class[id]
        next unless dest = sns.search_dupllicated_attachment(src)
        ids.push(dest.id)
        next if dest.id == src.id
        sns.delete_attachment(src)
        result.push(src: src.id, dest: dest.id)
      rescue => e
        errors.push(class: e.class.to_s, message: e.message, attachment_id: id)
      end
      body[attachment_field] = ids
      return body
    end
  end
end
