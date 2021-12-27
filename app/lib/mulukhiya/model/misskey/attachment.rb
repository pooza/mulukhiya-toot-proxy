module Mulukhiya
  module Misskey
    class Attachment < Sequel::Model(:drive_file)
      include Package
      include AttachmentMethods
      include SNSMethods
      many_to_one :account, key: :userId

      def to_h
        return values.deep_symbolize_keys.merge(
          acct: account.acct.to_s,
          file_name: name,
          file_size_str: size_str,
          type: type,
          mediatype: mediatype,
          created_at: date,
          created_at_str: date.strftime('%Y/%m/%d %H:%M:%S'),
          meta: meta,
          url: webpublicUrl || values[:url],
          thumbnail_url: thumbnailUrl,
          pixel_size: pixel_size,
          duration: duration,
        ).except(
          :properties,
        ).deep_compact
      end

      def meta
        unless @meta
          @meta = JSON.parse(values[:properties]).deep_symbolize_keys
          @meta.merge!(super) unless mediatype == 'image'
        end
        return @meta
      rescue
        return {}
      end

      def uri(size = 'original')
        case size
        when 'small', 'thumbnail'
          return MisskeyService.new.create_uri(thumbnailUrl || webpublicUrl || url)
        else
          return MisskeyService.new.create_uri(webpublicUrl || url)
        end
      end

      def date
        return createdAt.getlocal
      end

      def description
        return nil
      end

      def self.catalog(params = {})
        params[:page] ||= 1
        catalog = Postgres.instance.execute('media_catalog', query_params.merge(params))
        records = catalog.map do |row|
          attachment = self[row[:id]]
          note = Status[row[:status_id]]
          attachment.to_h.merge(status_url: note.uri.to_s)
        end
        return records if params[:q].present?
        storage = MediaCatalogRenderStorage.new
        storage[params] = records unless storage[params]
        return storage[params]
      end

      def self.feed(&block)
        return enum_for(__method__) unless block
        Postgres.instance.execute('media_catalog', query_params)
          .map {|row| row[:id]}
          .filter_map {|id| self[id] rescue nil}
          .map(&:feed_entry)
          .each(&block)
      end
    end
  end
end
