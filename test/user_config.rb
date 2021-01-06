require 'securerandom'

module Mulukhiya
  class UserConfigTest < TestCase
    def setup
      @user_config = UserConfig.new(account.id)
      @key1 = SecureRandom.hex(16)
      @key2 = SecureRandom.hex(16)
    end

    def test_edit
      assert_nil(@user_config["/#{@key1}"])
      assert_nil(@user_config["/#{@key1}/#{@key2}"])
      assert_nil(@user_config.raw[@key1])
      assert_nil(@user_config.raw.dig(@key1, @key2))

      @user_config.update(@key1 => {@key2 => '焼きのり'})
      assert_equal(@user_config["/#{@key1}/#{@key2}"], '焼きのり')
      assert_equal(@user_config.raw.dig(@key1, @key2), '焼きのり')

      @user_config.update(@key1 => nil)
      assert_nil(@user_config["/#{@key1}/#{@key2}"])
      assert_nil(@user_config.raw.dig(@key1, @key2))
    end

    def test_to_h
      assert_kind_of(Hash, @user_config.to_h)
    end

    def test_disable?
      assert_false(@user_config.disable?('yakinori'))
      assert_boolean(@user_config.disable?('youtube_nowplaying_url'))
    end
  end
end
