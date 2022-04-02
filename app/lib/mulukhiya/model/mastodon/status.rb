module Mulukhiya
  module Mastodon
    class Status < Sequel::Model(:statuses)
      include Package
      include StatusMethods
      include SNSMethods
      one_to_many :attachment
      many_to_one :account

      def acct
        return account.acct
      end

      alias local? local

      def public?
        return visibility.zero?
      end

      alias attachments attachment

      def uri
        @uri ||= create_status_uri(self[:url] || self[:uri])
        return @uri
      end

      def public_uri
        unless @public_uri
          if Environment.mastodon_type?
            service = sns_class.new
          else
            service = MastodonService.new
          end
          @public_uri = service.create_uri("/@#{account.username}/#{id}")
        end
        return @public_uri
      end

      def parser
        @parser ||= TootParser.new(text)
        return @parser
      end

      def visibility_name
        case visibility
        when 0
          return TootParser.visibility_name(:public)
        when 1
          return TootParser.visibility_name(:unlisted)
        when 2
          return TootParser.visibility_name(:private)
        when 3
          return TootParser.visibility_name(:direct)
        else
          return nil
        end
      end

      def visibility_icon
        return TootParser.visibility_icon(visibility_name)
      end

      def date
        return Time.parse(created_at.strftime('%Y/%m/%d %H:%M:%S GMT')).getlocal
      end

      def to_h
        @hash ||= values.deep_symbolize_keys.merge(
          id: id.to_s,
          created_at: date,
          created_at_str: date&.strftime('%Y/%m/%d %H:%M:%S'),
          body: parser.body,
          is_taggable: taggable?,
          footer: parser.footer,
          footer_tags: TagContainer.scan(parser.footer)
            .filter_map {|tag| Mastodon::HashTag.get(name: tag)}
            .map(&:to_h),
          visibility_name:,
          visibility_icon:,
        ).compact
        return @hash
      end

      def to_md
        return uri.to_md
      rescue => e
        e.log
        template = Template.new('status_clipping.md')
        template[:account] = account.to_h
        template[:status] = TootParser.new(text).to_md
        template[:url] = uri.to_s
        return template.to_s
      end
    end
  end
end
