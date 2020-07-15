module Mulukhiya
  module Meisskey
    class Application < CollectionModel
      def self.[](id)
        return Application.new(id)
      end

      alias scopes permissions

      private

      def collection_name
        return :apps
      end
    end
  end
end
