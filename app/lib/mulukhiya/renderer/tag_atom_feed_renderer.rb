require 'digest/sha1'

module Mulukhiya
  class TagAtomFeedRenderer < Ginseng::Web::AtomFeedRenderer
    include Package
    include SNSMethods
    attr_reader :logger, :tag, :limit

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

    def default_tag?
      return TagContainer.default_tag_bases.member?(tag)
    end

    def limit=(limit)
      @limit = limit
      @atom = nil
    end

    def params
      return {
        limit: limit,
        tag: tag,
        local: !default_tag?,
      }
    end

    def cache!
      File.write(path, fetch)
      logger.info(class: self.class.to_s, message: 'cached', params: params)
    end

    def path
      return File.join(
        Environment.dir,
        'tmp/cache/',
        "#{Digest::SHA1.hexdigest(params.to_json)}.atom",
      )
    end

    def exist?
      return File.exist?(path)
    end

    def to_s
      return nil unless exist?
      return File.read(path)
    end

    def record
      @record ||= hash_tag_class.get(tag: tag)
      return @record
    end

    def self.cache_all
      bar = ProgressBar.create(total: all.count) if Environment.rake?
      all do |renderer|
        bar&.increment
        renderer.cache!
      rescue => e
        logger.error(error: e, tag: renderer.tag)
      end
      bar&.finish
      puts all.map {|v| "updated: ##{v.tag} #{v.path}"}.join("\n") if Environment.rake?
    end

    def self.all
      return enum_for(__method__) unless block_given?
      tags = TagContainer.default_tag_bases.clone
      tags.concat(TagContainer.media_tag_bases)
      tags.concat(TagContainer.futured_tag_bases)
      tags.concat(TagContainer.field_tag_bases)
      tags.uniq.each do |tag|
        renderer = TagAtomFeedRenderer.new
        renderer.tag = tag
        next unless renderer.record
        yield renderer
      rescue => e
        logger.error(error: e, tag: tag)
      end
    end

    private

    def fetch
      return nil unless controller_class.feed?
      return nil unless record
      record.create_feed(params).each do |row|
        push(
          link: create_link(row[:uri]).to_s,
          title: create_title(row),
          author: row[:display_name] || "@#{row[:username]}@#{row[:domain]}",
          date: Time.parse("#{row[:created_at]} UTC").getlocal,
        )
      rescue => e
        logger.error(error: e, row: row)
      end
      @atom = nil
      return atom
    end

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
