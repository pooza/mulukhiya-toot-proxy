require 'securerandom'

module Mulukhiya
  class UserConfigTest < TestCase
    def setup
      @userconfig = UserConfig.new(Environment.test_account.id)
      @key1 = SecureRandom.hex(16)
      @key2 = SecureRandom.hex(16)
    end

    def test_edit
      assert_nil(@userconfig["/#{@key1}"])
      assert_nil(@userconfig["/#{@key1}/#{@key2}"])
      assert_nil(@userconfig.raw.dig(@key1))
      assert_nil(@userconfig.raw.dig(@key1, @key2))

      @userconfig.update(@key1 => {@key2 => '焼きのり'})
      assert_equal(@userconfig["/#{@key1}/#{@key2}"], '焼きのり')
      assert_equal(@userconfig.raw.dig(@key1, @key2), '焼きのり')

      @userconfig.update(@key1 => nil)
      assert_nil(@userconfig["/#{@key1}/#{@key2}"])
      assert_nil(@userconfig.raw.dig(@key1, @key2))
    end

    def test_to_h
      assert_kind_of(Hash, @userconfig.to_h)
    end

    def test_disable?
      assert_false(@userconfig.disable?('yakinori'))
      assert_boolean(@userconfig.disable?('youtube_nowplaying_url'))
    end
  end
end
