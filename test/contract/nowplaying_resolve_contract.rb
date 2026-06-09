module Mulukhiya
  class NowplayingResolveContractTest < TestCase
    def setup
      @contract = NowplayingResolveContract.new
    end

    def test_call
      assert_empty(@contract.call(title: 'song').errors)
      assert_empty(
        @contract.call(
          title: 'song', artist: 'a', album: 'b', source_app_name: 'Spotify', prefer: 'spotify',
        ).errors,
      )

      assert_false(@contract.call(title: nil).errors.empty?)
      assert_false(@contract.call(title: '').errors.empty?)
      assert_false(@contract.call({}).errors.empty?)
    end

    def test_rejects_oversize_title
      assert_false(@contract.call(title: 'x' * 201).errors.empty?)
    end
  end
end
