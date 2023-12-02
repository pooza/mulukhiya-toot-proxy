module Mulukhiya
  class ArtistParser
    include Package

    def initialize(source, depth = 0)
      @source = source.nfkc
      @depth = depth + 1
      @max_depth = 3
    end

    def parse
      patterns do |pattern_entry|
        next unless matches = @source.match(pattern_entry[:pattern])
        if pattern_entry[:delimited] && (@depth <= @max_depth)
          return @source.split(delimiters).inject(Set[]) do |artists, artist|
            artists.merge(ArtistParser.new(artist, @depth).parse)
          end
        end
        return Set.new(parse_part(matches, pattern_entry[:items]))
      end
      return Set[@source]
    rescue => e
      e.log
      return Set[@source]
    end

    alias exec parse

    private

    def parse_part(matches, items)
      artists = Set[]
      items.each_with_index do |item, i|
        next if item['drop']
        if item['split']
          artists.merge(matches[i + 1].split(delimiters).map(&:strip))
        else
          artists.add(matches[i + 1].strip)
        end
      end
      return artists
    end

    def patterns(&block)
      return enum_for(__method__) unless block
      config['/nowplaying/artist/parser/patterns'].map do |entry|
        {
          pattern: Regexp.new(entry['pattern']),
          delimited: entry['delimited'],
          items: entry['items'] || [],
        }
      end.each(&block)
    end

    def delimiters
      return Regexp.new(config['/nowplaying/artist/parser/delimiter/pattern'])
    end
  end
end
