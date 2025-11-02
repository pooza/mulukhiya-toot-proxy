module Mulukhiya
  module Misskey
    class Channel < Sequel::Model(:channel)
      include Package
      include SNSMethods

      def to_h
        return values.deep_symbolize_keys
      end

      def uri
        @uri ||= sns_class.new.create_uri("/channels/#{id}")
        return @uri
      end

      alias archived? isArchived

      alias sensitive? isSensitive
    end
  end
end
