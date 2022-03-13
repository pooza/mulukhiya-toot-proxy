module Mulukhiya
  module HashTagMethods
    include SNSMethods

    def raw_name
      return @raw_name || name
    end

    def uri
      @uri ||= sns_class.new.create_uri("/tags/#{name}")
      return @uri
    end

    def listable?
      return true
    end

    def default?
      return DefaultTagHandler.tags.member?(name)
    end

    def remote_default?
      return RemoteTagHandler.tags.member?(name)
    end

    def local?
      return false if default?
      return false if remote_default?
      return true
    end

    def feed_uri
      @feed_uri ||= sns_class.new.create_uri("/mulukhiya/feed/tag/#{raw_name}")
      return @feed_uri
    end

    def create_feed(params)
      return [] unless Postgres.config?
      params[:tag] = name
      params[:tag_id] = id rescue nil
      return Postgres.instance.exec('tag_timeline', params).map do |row|
        row[:display_name] = "@#{row[:username]}" unless row[:display_name].present?
        row
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def favorites
        favorites = {}
        Postgres.instance.exec('tagged_accounts').each do |row|
          parser = controller_class.parser_class.new(row[:note].downcase)
          parser.tags.each do |v|
            favorites[v] ||= 0
            favorites[v] += 1
          end
        end
        return favorites.sort_by {|_, v| v}.reverse.to_h
      rescue => e
        e.log
        return {}
      end
    end
  end
end
