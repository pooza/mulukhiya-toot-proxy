module Mulukhiya
  class UserConfigCommandContractTest < TestCase
    def setup
      @contract = UserConfigCommandContract.new
    end

    def test_call
      errors = @contract.call(command: 'user_config', tags: ['実況', 'エア番組'], webhook: {}, growi: {}, dropbox: {}, notify: {}, amazon: {}).errors
      assert(errors.empty?)

      errors = @contract.call(command: 'user_config', tags: ['実況', 111], webhook: {}, growi: {}, dropbox: {}, notify: {}, amazon: {}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tags: [], webhook: {}, growi: {url: 'https://growi.example.com', token: 'aa'}, dropbox: {}, notify: {}, amazon: {}).errors
      assert(errors.empty?)

      errors = @contract.call(command: 'user_config', tags: [], webhook: {}, growi: {url: 11, token: ''}, dropbox: {}, notify: {}, amazon: {}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tags: [], webhook: {}, growi: {url: 'https://growi.example.com', token: 11}, dropbox: {}, notify: {}, amazon: {}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tags: [], webhook: {}, growi: {}, dropbox: {token: 'aaa'}, notify: {}, amazon: {}).errors
      assert(errors.empty?)

      errors = @contract.call(command: 'user_config', tags: [], webhook: {}, growi: {}, dropbox: {token: 222}, notify: {}, amazon: {}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tags: [], webhook: {}, growi: {}, dropbox: {}, notify: {verbose: true, user_config: true}, amazon: {}).errors
      assert(errors.empty?)

      errors = @contract.call(command: 'user_config', tags: [], webhook: {}, growi: {}, dropbox: {}, notify: {verbose: 111}, amazon: {}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tags: [], webhook: {}, growi: {}, dropbox: {}, notify: {user_config: 111}, amazon: {}).errors
      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tags: [], webhook: {}, growi: {}, dropbox: {}, notify: {}, amazon: {affiliate: true}).errors
      assert(errors.empty?)

      errors = @contract.call(command: 'user_config', tags: [], webhook: {}, growi: {}, dropbox: {}, notify: {}, amazon: {affiliate: 333}).errors
      assert_false(errors.empty?)
    end
  end
end
