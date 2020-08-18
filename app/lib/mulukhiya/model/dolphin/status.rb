module Mulukhiya
  module Dolphin
    class Status < Mulukhiya::Misskey::Status
      many_to_one :account, key: :userId

      def self.tag_feed(params)
        return [] unless Postgres.config?
        return Postgres.instance.execute('tag_feed', params)
      end
    end
  end
end
