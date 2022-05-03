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
        unless @service
          if Environment.misskey_type?
            @service = sns_class.new
          else
            @service = MisskeyService.new
          end
        end
        return @service
      end

      def uri
        unless @uri
          @uri = Ginseng::URI.parse(self[:uri]) if self[:uri].present?
          @uri ||= service.create_uri("/notes/#{id}")
          @uri = create_status_uri(@uri)
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

      def to_h
        @hash ||= values.deep_symbolize_keys.merge(
          uri: uri.to_s,
          url: uri.to_s,
          public_url: public_uri.to_s,
          webui_url: webui_uri.to_s,
          created_at: date&.strftime('%Y/%m/%d %H:%M:%S'),
          body:,
          footer:,
          footer_tags: footer_tags.map(&:to_h),
          is_taggable: taggable?,
          visibility:,
          visibility_name:,
          attachments: data[:files],
        ).compact
        return @hash
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
    end
  end
end
