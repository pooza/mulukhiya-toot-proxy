module Mulukhiya
  class MsnURI < Ginseng::URI
    include Package

    def msn?
      return absolute? && config['/msn/hosts'].member?(host)
    end

    alias valid? msn?

    def shortenable?
      return false unless msn?
      return false unless entry = config['/msn/patterns'].find {|v| path.match(v['pattern'])}
      return entry['shortenable']
    end

    def shorten
      return self unless shortenable?
      dest = clone
      pattern = Regexp.new(config['/msn/patterns'].find {|v| path.match(v['pattern'])}['pattern'])
      dest.path = dest.path.gsub("#{path.match(pattern)[2]}/", '')
      return dest
    end
  end
end
