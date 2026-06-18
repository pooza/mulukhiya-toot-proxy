module Mulukhiya
  class NowplayingResolveUrlContractTest < TestCase
    def setup
      @contract = NowplayingResolveUrlContract.new
    end

    def test_accepts_valid_url
      errors = @contract.call(url: 'https://music.apple.com/jp/album/1299587212?i=1299587213').errors

      assert_empty(errors)
    end

    def test_rejects_missing_url
      errors = @contract.call({}).errors

      assert_false(errors.empty?)
    end

    def test_rejects_blank_url
      errors = @contract.call(url: '').errors

      assert_false(errors.empty?)
    end

    def test_rejects_non_http_url
      errors = @contract.call(url: 'spotify:track:abc').errors

      assert_false(errors.empty?)
    end

    def test_rejects_oversized_url
      errors = @contract.call(url: "https://example.com/#{'a' * NowplayingResolveUrlContract::MAX_URL_SIZE}").errors

      assert_false(errors.empty?)
    end
  end
end
