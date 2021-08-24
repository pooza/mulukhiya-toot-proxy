module Mulukhiya
  class ArtistParser
    include Package

    def initialize(source, depth = 0)
      @source = source.nfkc
      @depth = depth + 1
      @max_depth = 3
    end

    def parse
      tags = Set[]
      patterns do |pattern_entry|
        next unless matches = @source.match(pattern_entry[:pattern])
        if pattern_entry[:delimited] && (@depth <= @max_depth)
          @source.split(delimiters).each do |artist|
            tags.merge(ArtistParser.new(artist, @depth).parse)
          end
        else
          tags.merge(parse_part(matches, pattern_entry[:items]))
        end
        return tags
      end
      return Set[@source]
    rescue => e
      logger.error(error: e)
      return Set[@source]
    end

    alias exec parse

    private

    def parse_part(matches, items)
      tags = []
      items.each_with_index do |item, i|
        next if item['drop']
        if item['split']
          tags.concat(matches[i + 1].split(delimiters).map(&:strip))
        else
          tags.push(matches[i + 1].strip)
        end
      end
      return tags
    end

    def patterns
      return enum_for(__method__) unless block_given?
      config['/nowplaying/artist/parser/patterns'].each do |entry|
        output = {
          pattern: Regexp.new(entry['pattern']),
          delimited: entry['delimited'],
          items: (entry['items'] || []),
        }
        yield output
      end
    end

    def delimiters
      return Regexp.new(config['/nowplaying/artist/parser/delimiter/pattern'])
    end
  end
end
