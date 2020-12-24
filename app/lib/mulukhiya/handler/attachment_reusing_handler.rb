module Mulukhiya
  class AttachmentReusingHandler < Handler
    def handle_pre_toot(body, params = {})
      ids = []
      body[attachment_field].clone.each do |id|
        next unless attachment = sns.uploaded_attachment(Environment.attachment_class[id])
        ids.push(attachment.id)
        sns.delete_attachment(id) unless attachment.id == id
      rescue => e
        errors.push(class: e.class.to_s, message: e.message, attachment_id: id)
      end
      body[attachment_field] = ids
      return body
    end
  end
end
