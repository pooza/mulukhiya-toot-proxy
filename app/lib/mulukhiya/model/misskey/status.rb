module Mulukhiya
  module Misskey
    class Status < Sequel::Model(:note)
      include Package
      include StatusMethods
      include SNSMethods
      many_to_one :account, key: :userId

      def local?
        return userHost.nil?
      end

      def service
        @service ||= MisskeyService.new
        return @service
      end

      def uri
        unless @uri
          if self[:uri].present?
            uri = Ginseng::URI.parse(self[:uri])
          else
            uri = self.class.create_uri(:public, {id:})
          end
          @uri = create_status_uri(uri)
        end
        return @uri
      end

      def date
        return MisskeyService.parse_aid(id)
      end

      alias public_uri uri

      def updatable_by?(target)
        target = Account[target] unless target.is_a?(Account)
        return account&.id == target&.id
      end

      def poll
        return nil unless hasPoll
        return Poll[id]
      end

      def attachments
        @attachments ||= fileIds.match(/\{(.*)\}/)[1].split(',').map do |id|
          Attachment[id]
        end
        return @attachments
      rescue => e
        e.log
        return []
      end

      alias visibility_name visibility

      def payload
        payload = super
        payload[attachment_field.to_sym] = attachments.map(&:id).to_a
        return payload
      end

      def to_md
        return uri.to_md
      rescue => e
        e.log
        template = Template.new('status_clipping.md')
        template[:account] = account.to_h
        template[:status] = NoteParser.new(text).to_md
        template[:url] = uri.to_s
        return template.to_s
      end

      def self.create_uri(type, params)
        type ||= :public
        service = MisskeyService.new
        params[:id] ||= params[:status_id]
        case type.to_sym
        in :public
          return service.create_uri("/notes/#{params[:id]}")
        end
      end
    end
  end
end
