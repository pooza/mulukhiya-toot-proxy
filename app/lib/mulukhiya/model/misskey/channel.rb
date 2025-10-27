module Mulukhiya
  module Misskey
    class Channel < Sequel::Model(:channel)
      include Package
      include SNSMethods

      def to_h
        return values.deep_symbolize_keys
      end

      alias archived? isArchived

      alias sensitive? isSensitive
    end
  end
end
