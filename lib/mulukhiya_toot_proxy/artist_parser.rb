module MulukhiyaTootProxy
  class ArtistParser
    def initialize(source)
      @source = source
      @tags = []
    end

    def parse
      dest = @source.sub(prefixes_pattern, '')
      cv_patterns do |pattern_entry|
        next unless matches = dest.match(pattern_entry[:pattern])
        i = 1
        pattern_entry[:items].each do |item|
          split_artist(matches[i], item['split']).each do |tag|
            @tags.push(create_tag(tag, item['strip'], item['prefix']))
          end
          i += 1
        end
        break
      end
      @tags.uniq!
      @tags.compact!
      return @tags if @tags.present?
      return [Mastodon.create_tag(dest)]
    rescue
      return [Mastodon.create_tag(@source)]
    end

    def self.delimiters_pattern
      return Regexp.new(
        "[#{Config.instance['/artist_parser/delimiters'].join}]",
      )
    end

    private

    def prefixes_pattern
      return Regexp.new(
        "^(#{Config.instance['/artist_parser/prefixes'].join('|')}):",
      )
    end

    def cv_patterns
      return enum_for(__method__) unless block_given?
      Config.instance['/artist_parser/cv_patterns'].each do |entry|
        entry = {
          pattern: Regexp.new(entry['pattern']),
          items: entry['items'],
        }
        yield entry
      end
    end

    def create_tag(tag, strip, prefix)
      tag = Mastodon.create_tag(tag)
      tag.tr!('_', '') if strip
      tag = "#{prefix}#{tag}" if prefix
      return tag
    end

    def split_artist(artist, flag)
      return artist.split(ArtistParser.delimiters_pattern) if flag
      return [artist]
    end
  end
end
