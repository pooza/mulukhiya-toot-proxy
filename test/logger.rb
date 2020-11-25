module Mulukhiya
  class LoggerTest < TestCase
    def setup
      @logger = Logger.new
    end

    def test_create_message
      assert_equal(@logger.create_message('string'), 'string')
      raise Ginseng::AuthError, 'unauthorized'
    rescue Ginseng::AuthError => e
      assert_equal(@logger.create_message(error: e, class: self.class.to_s), {
        error: {
          message: 'unauthorized',
          file: 'test/logger.rb',
          line: 9,
        },
        class: 'Mulukhiya::LoggerTest',
      })
    end
  end
end
