module Mulukhiya
  class Acct < Ginseng::Fediverse::Acct
    include Package
    attr_accessor :host

    def domain_name
      return nil if local?
      return host
    end

    alias domain domain_name

    def local?
      return host == Environment.domain_name
    end

    def agent?
      return config['/agent/accts'].member?(contents)
    end
  end
end
