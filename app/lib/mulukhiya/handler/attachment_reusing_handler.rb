module Mulukhiya
  class AttachmentReusingHandler < Handler
    def handle_pre_toot(payload, params = {})
      return unless payload[attachment_field]
      ids = []
      payload[attachment_field].map {|id| attachment_class[id]}.each do |src|
        next unless dest = sns.search_dupllicated_attachment(src)
        ids.push(dest.id)
        next if dest.id == src.id
        sns.delete_attachment(src)
        result.push(src: src.id, dest: dest.id)
      rescue => e
        errors.push(class: e.class.to_s, message: e.message, attachment_id: id)
      end
      payload[attachment_field] = ids
    end
  end
end
