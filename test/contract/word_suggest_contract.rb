module Mulukhiya
  class WordSuggestContractTest < TestCase
    def setup
      @contract = WordSuggestContract.new
    end

    def test_call
      assert_empty(@contract.call(q: 'あい').errors)
      assert_empty(@contract.call(q: 'あい', limit: '10').errors)

      assert_false(@contract.call(q: nil).errors.empty?)
      assert_false(@contract.call({}).errors.empty?)
    end
  end
end
