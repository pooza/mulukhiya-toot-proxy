module Mulukhiya
  module Meisskey
    class Attachment
      attr_reader :id

      def initialize(id)
        @id = id.to_s
        @logger = Logger.new
      end

      def values
        @values ||= Attachment.collection.find(_id: BSON::ObjectId.from_string(id)).first.to_h
        return @values
      end

      def file_content_type
        return values['contentType']
      end

      alias type file_content_type

      def uri
        @uri ||= Ginseng::URI.parse(values['src'] || values['uri'])
        return @uri
      end

      def self.[](id)
        return Attachment.new(id)
      end

      def self.collection
        return Mongo.instance.db['driveFiles.files']
      end
    end
  end
end
