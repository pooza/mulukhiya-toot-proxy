require 'test/unit'

module MulukhiyaTootProxy
  class HandlerTest < Test::Unit::TestCase
    def message_field
      return Environment.sns_class.message_field
    end
  end
end
