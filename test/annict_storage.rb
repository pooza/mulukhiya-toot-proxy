module Mulukhiya
  class AnnictStorageTest < TestCase
    def setup
      @storage = AnnictStorage.new
    end

    def test_account_ids
      @storage.account_ids do |id|
        assert_kind_of([String, Integer], id)
      end
    end
  end
end
