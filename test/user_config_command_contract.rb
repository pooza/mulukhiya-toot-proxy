module Mulukhiya
  class UserConfigCommandContractTest < TestCase
    def setup
      @contract = UserConfigCommandContract.new
    end

    def test_call
      errors = @contract.call(command: 'user_config', growi: {url: 'https://growi.example.com', token: 'aa'}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', growi: {url: 11, token: ''}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', growi: {url: 'https://growi.example.com', token: 11}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', annict: {token: 'aaa'}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', annict: {token: 222}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', notify: {verbose: true}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', notify: {verbose: 111}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', lemmy: {url: 111}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', lemmy: {url: 'https://lm.korako.me'}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', lemmy: {user: 111}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', lemmy: {user: 'pooza@b-shock.org'}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', lemmy: {password: 111}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', lemmy: {password: 'you_pass_word'}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', lemmy: {community: 'community_name'}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', lemmy: {community: 111}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', nextcloud: {url: 111}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', nextcloud: {url: 'https://nextcloud.example.com'}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', nextcloud: {user: 111}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', nextcloud: {user: 'pooza'}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', nextcloud: {password: 111}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', nextcloud: {password: 'you_pass_word'}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', tagging: nil).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', tagging: {user_tags: nil}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', tagging: {user_tags: [1, 3]}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tagging: {user_tags: ['tag1', 'tag2']}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', tagging: {user_tags: ['tag1', 'tag2'], minutes: 'hoge'}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tagging: {user_tags: ['tag1', 'tag2'], minutes: 1.2}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tagging: {user_tags: ['tag1', 'tag2'], minutes: 30}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', tagging: {tags: {disabled: nil}}).errors

      assert_empty(errors)

      errors = @contract.call(command: 'user_config', tagging: {tags: {disabled: [1, 3]}}).errors

      assert_false(errors.empty?)

      errors = @contract.call(command: 'user_config', tagging: {tags: {disabled: ['tag1', 'tag2']}}).errors

      assert_empty(errors)
    end
  end
end
