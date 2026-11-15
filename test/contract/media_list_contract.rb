module Mulukhiya
  class MediaListContractTest < TestCase
    def setup
      @contract = MediaListContract.new
    end

    def test_call
      errors = @contract.call({}).errors

      assert_empty(errors)

      errors = @contract.call(page: 0).errors

      assert_false(errors.empty?)

      errors = @contract.call(page: 1).errors

      assert_empty(errors)

      errors = @contract.call(page: 2).errors

      assert_empty(errors)

      errors = @contract.call(only_person: 1).errors

      assert_empty(errors)

      errors = @contract.call(only_person: 0).errors

      assert_empty(errors)

      errors = @contract.call(only_person: 'false').errors

      assert_false(errors.empty?)

      errors = @contract.call(q: 0).errors

      assert_false(errors.empty?)

      errors = @contract.call(q: 'キュアホワイトうどん').errors

      assert_empty(errors)

      # ⚠ Pleroma 系の cursor は `<FlakeId>.<位置>` の 2 つ組（#4911）。
      errors = @contract.call(cursor: Environment.pleroma? ? 'BBRwXUDu0uwfOACCsy.1' : '12345').errors

      assert_empty(errors)

      errors = @contract.call(cursor: 123).errors

      assert_false(errors.empty?)
    end
  end
end
