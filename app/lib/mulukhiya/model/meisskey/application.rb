module Mulukhiya
  module Meisskey
    class Application < CollectionModel
      def permission
        return values['permission'].join(' ')
      end

      def self.[](id)
        return Application.new(id)
      end

      private

      def collection_name
        return :apps
      end
    end
  end
end
