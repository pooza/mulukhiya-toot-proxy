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
      assert_equal('焼きのり', @user_config["/#{@key1}/#{@key2}"])
      assert_equal('焼きのり', @user_config.raw.dig(@key1, @key2))

      @user_config.update(@key1 => nil)
      assert_nil(@user_config["/#{@key1}/#{@key2}"])
      assert_nil(@user_config.raw.dig(@key1, @key2))
    end

    def test_to_h
      assert_kind_of(Hash, @user_config.to_h)
    end

    def test_to_json
      assert_kind_of(Hash, JSON.parse(@user_config.to_json))
    end

    def test_to_s
      assert_kind_of(String, @user_config.to_s)
    end

    def test_encrypt
      values = @user_config.encrypt(sample: {password: 'bbb'}, token: 2222, foo: '焼きそば')
      assert_equal('焼きそば', values['foo'])
      assert_equal('2222', values['token'].decrypt)
      assert_equal('bbb', values.dig('sample', 'password').decrypt)
    end

    def test_disable?
      assert_false(@user_config.disable?('yakinori'))
      assert_boolean(@user_config.disable?('you_tube_url_nowplaying'))
    end
  end
end
