module Mulukhiya
  class UserConfigCommandContractTest < TestCase
    def setup
      @contract = UserConfigCommandContract.new
    end

    def test_call
      errors = @contract.call(command: 'user_config', service: {annict: {token: 'aaa'}}).errors.messages

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', service: {annict: {token: 222}}).errors.messages

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', notify: {verbose: true}).errors.messages

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', notify: {verbose: 111}).errors.messages

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tagging: nil).errors.messages

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', tagging: {user_tags: nil}).errors.messages

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', tagging: {user_tags: [1, 3]}).errors.messages

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tagging: {user_tags: ['tag1', 'tag2']}).errors.messages

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', tagging: {user_tags: ['tag1', 'tag2'], minutes: 'hoge'}).errors.messages

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tagging: {user_tags: ['tag1', 'tag2'], minutes: 1.2}).errors.messages

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tagging: {user_tags: ['tag1', 'tag2'], minutes: 30}).errors.messages

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', tagging: {tags: {disabled: nil}}).errors.messages

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', tagging: {tags: {disabled: [1, 3]}}).errors.messages

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tagging: {tags: {disabled: ['tag1', 'tag2']}}).errors.messages

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', decoration: nil).errors.messages

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', decoration: {id: 'abc123'}).errors.messages

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', decoration: {id: 123}).errors.messages

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', decoration: {minutes: 30}).errors.messages

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', decoration: {minutes: 'hoge'}).errors.messages

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', decoration: {id: 'abc123', minutes: 30}).errors.messages

      assert_empty(errors)
    end
  end
end
