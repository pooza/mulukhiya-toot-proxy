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
        return createdAt.getlocal
      end

      alias public_uri uri

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
