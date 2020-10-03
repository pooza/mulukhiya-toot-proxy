require 'digest/sha1'

module Mulukhiya
  class TagAtomFeedRenderer < Ginseng::Web::AtomFeedRenderer
    include Package
    attr_reader :logger, :tag, :limit

    def initialize(channel = {})
      super
      @sns = Environment.sns_class.new
      @channel[:author] = @sns.info['metadata']['maintainer']['name']
      @limit = @config['/feed/tag/limit']
    end

    def tag=(tag)
      @tag = tag
      @channel.merge!(
        title: "##{tag} | #{@sns.info['metadata']['nodeName']}",
        link: record.uri.to_s,
        description: "#{@sns.info['metadata']['nodeName']} ##{tag}のタイムライン",
      )
      @atom = nil
    end

    def limit=(limit)
      @limit = limit
      @atom = nil
    end

    def params
      return {
        limit: limit,
        tag: tag,
        test_usernames: @config['/feed/test_usernames'],
      }
    end

    def cache!
      File.write(path, fetch)
      @logger.info(action: 'cached', params: params)
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
      @record ||= Environment.hash_tag_class.get(tag: tag)
      return @record
    end

    def self.cache_all
      all do |renderer|
        renderer.cache!
      rescue => e
        renderer.logger.error(Ginseng::Error.create(e).to_h.merge(tag: renderer.tag))
      end
    end

    def self.all
      return enum_for(__method__) unless block_given?
      config = Config.instance
      TagContainer.default_tag_bases.each do |tag|
        renderer = TagAtomFeedRenderer.new
        renderer.tag = tag
        yield renderer
      end
      return unless config['/tagging/media/enable']
      ['image', 'video', 'audio'].freeze.each do |key|
        renderer = TagAtomFeedRenderer.new
        renderer.tag = config["/tagging/media/tags/#{key}"]
        yield renderer
      end
    end

    private

    def fetch
      return nil unless Environment.controller_class.tag_feed?
      return nil unless record
      record.create_feed(params).each do |row|
        push(
          link: create_link(row[:uri]).to_s,
          title: create_title(row),
          author: row[:display_name] || "@#{row[:username]}@#{row[:domain]}",
          date: Time.parse("#{row[:created_at]} UTC").getlocal,
        )
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
      dest = Environment.sns_class.new.create_uri(src) unless dest.absolute?
      generic = dest.clone
      dest = TootURI.parse(generic.to_s)
      dest = NoteURI.parse(generic.to_s) unless dest.valid?
      return dest.publicize if dest.valid?
      return generic
    end
  end
end
