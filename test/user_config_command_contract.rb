module Mulukhiya
  class UserConfigCommandContractTest < TestCase
    def setup
      @contract = UserConfigCommandContract.new
    end

    def test_call
      errors = @contract.call(command: 'user_config', tags: ['実況', 'エア番組']).errors
      assert(errors.empty?)

      errors = @contract.call(command: 'user_config', tags: ['実況', 111]).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', growi: {url: 'https://growi.example.com', token: 'aa'}).errors
      assert(errors.empty?)

      errors = @contract.call(command: 'user_config', growi: {url: 11, token: ''}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', growi: {url: 'https://growi.example.com', token: 11}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', dropbox: {token: 'aaa'}).errors
      assert(errors.empty?)

      errors = @contract.call(command: 'user_config', dropbox: {token: 222}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', annict: {token: 'aaa'}).errors
      assert(errors.empty?)

      errors = @contract.call(command: 'user_config', annict: {token: 222}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', twitter: {token: 'aaa', secret: 'bbb'}).errors
      assert(errors.empty?)

      errors = @contract.call(command: 'user_config', twitter: {token: 222}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', twitter: {secret: 222}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', notify: {verbose: true, user_config: true}).errors
      assert(errors.empty?)

      errors = @contract.call(command: 'user_config', notify: {verbose: 111}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', notify: {user_config: 111}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', amazon: {affiliate: true}).errors
      assert(errors.empty?)

      errors = @contract.call(command: 'user_config', amazon: {affiliate: 333}).errors
      assert_false(errors.empty?)
    end
  end
end
