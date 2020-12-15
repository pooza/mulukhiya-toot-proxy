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
      @logger.info(class: self.class.to_s, message: 'cached', params: params)
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

    def self.cache_all(params = {})
      all(params) do |renderer|
        renderer.cache!
      rescue => e
        renderer.logger.error(error: e, tag: renderer.tag)
      end
      all do |renderer|
        puts "updated: ##{renderer.tag} #{renderer.path}" if params[:console]
      end
    end

    def self.all(params = {})
      return enum_for(__method__, params) unless block_given?
      tags = TagContainer.default_tag_bases.clone
      tags.concat(TagContainer.media_tag_bases)
      tags.concat(TagContainer.futured_tag_bases)
      tags.uniq!
      bar = ProgressBar.create(total: tags.count) if params[:console]
      tags.each do |tag|
        bar.increment if params[:console]
        renderer = TagAtomFeedRenderer.new
        renderer.tag = tag
        yield renderer
      end
      bar.finish if params[:console]
    end

    private

    def fetch
      return nil unless Environment.controller_class.feed?
      return nil unless record
      record.create_feed(params).each do |row|
        push(
          link: create_link(row[:uri]).to_s,
          title: create_title(row),
          author: row[:display_name] || "@#{row[:username]}@#{row[:domain]}",
          date: Time.parse("#{row[:created_at]} UTC").getlocal,
        )
      rescue => e
        @logger.error(error: e, row: row)
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
