module Mulukhiya
  module Meisskey
    class Attachment < MongoCollection
      include AttachmentMethods

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            id: id,
            acct: account.acct.to_s,
            file_name: name,
            file_size_str: size_str,
            type: type,
            mediatype: mediatype,
            created_at: date,
            created_at_str: date.strftime('%Y/%m/%d %H:%M:%S'),
            meta: meta,
            url: uri.to_s,
            thumbnail_url: values.dig('metadata', 'thumbnailUrl'),
            pixel_size: pixel_size,
            duration: duration,
          )
          @hash.deep_compact!
        end
        return @hash
      end

      def feed_entry
        return {
          link: uri.to_s,
          title: "#{name} (#{size_str}) #{description}",
          author: account.display_name,
          date: date,
        }
      end

      def account
        return Account[values.dig('metadata', 'userId')]
      end

      def type
        return contentType
      end

      def uri
        @uri ||= Ginseng::URI.parse(values['src'] || values.dig('metadata', 'url'))
        return @uri
      end

      def meta
        unless @meta
          @meta = values.dig('metadata', 'properties')
          @meta.merge!(super) unless mediatype == 'image'
        end
        return @meta
      rescue
        return {}
      end

      def date
        return values['uploadDate']
      end

      def name
        return values['filename']
      end

      def size
        return values['length']
      end

      def self.[](id)
        return Attachment.new(id)
      end

      def self.catalog(params = {})
        return enum_for(__method__, params) unless block_given?
        statuses(params[:page]).each do |status|
          status[:_files].each do |row|
            note = Attachment[row[:_id]]
            yield note.to_h.deep_symbolize_keys.merge(
              date: note.createdAt,
              status_url: note.uri.to_s,
            )
          rescue => e
            logger.error(error: e, row: row)
          end
        end
      end

      def self.feed
        return enum_for(__method__) unless block_given?
        statuses.each do |status|
          status[:_files].each do |row|
            yield Attachment[row[:_id]].feed_entry
          rescue => e
            logger.error(error: e, row: row)
          end
        end
      end

      def self.statuses(page = 1)
        page ||= 1
        rows = Status.collection.aggregate([
          {'$sort' => {'createdAt' => -1}},
          {'$lookup' => {from: 'users', localField: 'userId', foreignField: '_id', as: 'user'}},
          {'$match' => {
            'fileIds' => {'$ne' => nil},
            'user.isBot' => false,
            '_user.host' => nil,
            'visibility' => {'$in' => ['public', 'home']},
          }},
          {'$skip' => config['/feed/media/limit'] * (page - 1)},
          {'$limit' => config['/feed/media/limit'] * page},
        ])
        return rows
      end

      def self.collection
        return Mongo.instance.db['driveFiles.files']
      end

      private

      def collection_name
        return 'driveFiles.files'
      end
    end
  end
end
