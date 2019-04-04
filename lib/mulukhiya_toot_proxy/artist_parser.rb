module MulukhiyaTootProxy
  class ArtistParser
    def initialize(source)
      @source = source
      @config = Config.instance
      @logger = Logger.new
      @tags = []
    end

    def parse
      return [@source] unless @config['/nowplaying/hashtag']
      patterns do |pattern_entry|
        next unless matches = @source.match(pattern_entry[:pattern])
        if pattern_entry[:delimited]
          split_artist(@source, true).each do |artist|
            @tags.concat(ArtistParser.new(artist).parse)
          end
        else
          @tags.concat(parse_part(matches, pattern_entry[:items]))
        end
        break
      end
      @tags.uniq!
      @tags.compact!
      return @tags if @tags.present?
      return [Mastodon.create_tag(@source)]
    rescue => ex
      @logger.error(Ginseng::Error.create(ex).to_h)
      return [Mastodon.create_tag(@source)]
    end

    private

    def parse_part(source, items)
      i = 0
      tags = []
      items.each do |item|
        i += 1
        next if item['drop']
        split_artist(source[i], item['split']).each do |tag|
          tags.push(create_tag(tag, item['strip'], item['prefix']))
        end
      end
      return tags
    end

    def patterns
      return enum_for(__method__) unless block_given?
      @config['/nowplaying/artist_parser/patterns'].each do |entry|
        output = {
          pattern: Regexp.new(entry['pattern']),
          delimited: entry['delimited'],
        }
        output[:items] = entry['items'] || []
        yield output
      end
    end

    def create_tag(tag, strip, prefix)
      tag = Mastodon.create_tag(tag)
      tag.tr!('_', '') if strip
      tag = "#{prefix}#{tag}" if prefix
      return tag
    end

    def split_artist(artist, flag)
      pattern = Regexp.new("[#{Config.instance['/nowplaying/artist_parser/delimiters'].join}]")
      return flag ? artist.split(pattern) : [artist]
    end
  end
end
