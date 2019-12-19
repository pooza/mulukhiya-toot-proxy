require 'test/unit'

module MulukhiyaTootProxy
  class TestCase < Test::Unit::TestCase
    def message_field
      return Environment.sns_class.message_field
    end

    def invalid_handler?
      return @handler.nil? || @handler.disable?
    end
  end
end
