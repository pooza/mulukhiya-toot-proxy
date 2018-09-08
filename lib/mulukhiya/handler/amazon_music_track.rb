require 'mulukhiya/amazon_service'
require 'mulukhiya/handler'
require 'mulukhiya/slack'

module MulukhiyaTootProxy
  class AmazonMusicTrackHandler < Handler
    def exec(body, headers = {})
      lines = []
      updated = false
      body['status'].each_line do |line|
        lines.push(line)
        next if updated
        next unless matches = line.strip.match(/^#nowplaying\s(.*)$/i)
        keyword = matches[1]
        updated = true
        amazon = AmazonService.new
        next unless asin = amazon.search(keyword, 'Music')
        uri = amazon.item_uri(asin)
        uri.associate_tag = AmazonService.associate_tag
        lines.push(uri.to_s)
      end
      body['status'] = lines.join("\n")
    end
  end
end
