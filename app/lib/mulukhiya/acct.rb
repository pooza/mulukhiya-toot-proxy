module Mulukhiya
  class Acct < Ginseng::Fediverse::Acct
    include Package
    attr_accessor :host

    def domain_name
      return nil if host == Environment.domain_name
      return host
    end

    alias domain domain_name

    def agent?
      @config['/agent/accts'].member?(contents)
    end
  end
end
