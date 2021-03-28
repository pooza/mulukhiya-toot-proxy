module Mulukhiya
  class TagFeedRenderer < Ginseng::Web::AtomFeedRenderer
    include Package
    include SNSMethods
    attr_reader :tag, :limit

    def initialize(channel = {})
      super
      @sns = sns_class.new
      @channel[:author] = @sns.info['metadata']['maintainer']['name']
      @limit = config['/feed/tag/limit']
    end

    def tag=(tag)
      @tag = tag.to_hashtag_base
      @channel[:link] = record.uri.to_s
      @channel[:title] = "##{tag} | #{@sns.info['metadata']['nodeName']}"
      @channel[:description] = "#{@sns.info['metadata']['nodeName']} ##{tag}のタイムライン"
      @atom = nil
    rescue => e
      logger.error(error: e, tag: tag)
      @tag = nil
      @atom = nil
    end

    def limit=(limit)
      @limit = limit
      @atom = nil
    end

    def exist?
      return @record&.listable? || false rescue false
    end

    def record
      unless @record
        return nil unless @record = hash_tag_class.get(tag: tag&.downcase)
        @record.raw_name = tag
      end
      return @record
    end

    def to_s
      fetch
      return super
    end

    def fetch
      @atom = nil
      return nil unless controller_class.feed?
      return nil unless record
      record.create_feed({limit: limit, tag: tag, local: record.local?}).each do |row|
        push(
          link: create_link(row[:uri]).to_s,
          title: create_title(row),
          author: row[:display_name] || "@#{row[:username]}@#{row[:domain]}",
          date: Time.parse("#{row[:created_at]} UTC").getlocal,
        )
      rescue => e
        logger.error(error: e, row: row)
      end
    end

    private

    def create_title(row)
      template = Template.new('feed_entry')
      template[:row] = row
      return template.to_s.chomp.sanitize
    end

    def create_link(src)
      dest = Ginseng::URI.parse(src)
      dest = sns_class.new.create_uri(src) unless dest.absolute?
      generic = dest.clone
      dest = TootURI.parse(generic.to_s)
      dest = NoteURI.parse(generic.to_s) unless dest.valid?
      return dest.publicize if dest.valid?
      return generic
    end
  end
end
