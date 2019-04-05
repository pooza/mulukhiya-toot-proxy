require 'unicode'

module MulukhiyaTootProxy
  class TaggingHandler < Handler
    def exec(body, headers = {})
      container = TagContainer.new
      container.body = Unicode.nfkc(body['status'])
      tmp_body = container.body.clone
      TaggingDictionary.new.reverse_each do |k, v|
        next if k.length < @config['/tagging/word/minimum_length']
        next unless tmp_body =~ v[:pattern]
        container.push(k)
        container.concat(v[:words])
        tmp_body.gsub!(v[:pattern], '')
      end
      tags = container.create_tags
      body['status'] = append(body['status'], tags)
      @count += tags.count
      return body
    end

    private

    def append(body, tags)
      return body unless tags.present?
      lines = body.each_line.map(&:chomp).to_a
      if lines.last&.match?(Regexp.new("^(#[[:word:]]+\s*)+$", Regexp::IGNORECASE))
        line = lines.pop
        body = lines.join("\n")
        line.split(/\s/).reverse_each do |tag|
          tags.unshift(tag)
        end
        tags.uniq!
        tags.compact!
      end
      return [body, tags.join(' ')].join("\n")
    end
  end
end
