module Mulukhiya
  class ItuneskURI < Ginseng::URI
    include Package

    def self.parse(url)
      types.each do |type|
        pattern = Regexp.new(config["/itunes/patterns/#{type}"])
        pp patterm
        # if pattern.match(url)
        #  return "Mulukhiya::Itunes#{type.to_s.camelize}URI".constantize.parse(url)
        # end
      end
    end

    def self.types
      return [:track, :album, :song]
    end
  end
end
