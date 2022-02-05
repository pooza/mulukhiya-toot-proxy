module Mulukhiya
  class TagFeedRenderer < Ginseng::Web::AtomFeedRenderer
    include Package
    include SNSMethods
    attr_reader :tag, :limit

    def initialize(channel = {})
      super
      @sns = sns_class.new
      @channel[:author] = @sns.maintainer_name
      @limit = config['/feed/tag/limit']
    end

    def tag=(tag)
      @tag = tag.to_hashtag_base
      @channel[:link] = record.uri.to_s
      @channel[:title] = "##{tag} | #{@sns.node_name}"
      @channel[:description] = "#{@sns.node_name} ##{tag}のタイムライン"
      @atom = nil
    rescue => e
      e.log(tag:)
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
      record.create_feed({limit:, tag:, local: record.local?}).each do |row|
        push(
          link: create_link(row[:uri]).to_s,
          title: create_title(row),
          author: row[:display_name],
          date: Time.parse("#{row[:created_at]} UTC").getlocal,
        )
      rescue => e
        e.log(row:)
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
      dest = create_status_uri(generic.to_s)
      return dest.publicize if dest&.valid?
      return generic
    end
  end
end
