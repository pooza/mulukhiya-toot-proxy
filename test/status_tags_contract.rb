module Mulukhiya
  class StatusTagsContractTest < TestCase
    def setup
      @contract = StatusTagsContract.new
    end

    def test_call
      errors = @contract.call({}).errors

      assert_false(errors.empty?)

      errors = @contract.call(id: 'zxxxxx').errors

      assert_false(errors.empty?)

      errors = @contract.call(tag: 'delmulin').errors

      assert_false(errors.empty?)

      errors = @contract.call(id: 'aaaaaaacdfg', tag: '#').errors

      assert_false(errors.empty?)

      errors = @contract.call(id: 'aaaaaaacdfg', tags: []).errors

      assert_empty(errors)

      errors = @contract.call(id: 'aaaaaaacdfg', tags: [1]).errors

      assert_false(errors.empty?)

      errors = @contract.call(id: 'aaaaaaacdfg', tags: ['precure_fun']).errors

      assert_empty(errors)

      errors = @contract.call(id: 'aaaaaaacdfg', tags: ['precure_fun', 1]).errors

      assert_false(errors.empty?)

      errors = @contract.call(id: 'aaaaaaacdfg', tags: ['precure_fun', 'キュアソード']).errors

      assert_empty(errors)
    end
  end
end
