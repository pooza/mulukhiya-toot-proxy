module Mulukhiya
  class Crypt < Ginseng::Crypt
    include Package

    def self.config?
      return password.present?
    end

    def self.password
      return config['/crypt/password'] rescue nil
    end
  end
end
