module Mulukhiya
  module Misskey
    class Poll < Sequel::Model(:poll)
      one_to_one :status, key: :noteId

      def choices
        return values[:choices].match(/\{(.*)\}/)[1].split(',')
      end
    end
  end
end
