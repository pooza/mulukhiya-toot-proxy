module Mulukhiya
  class AnnictStorageTest < TestCase
    def test_accounts
      AnnictStorage.accounts do |account|
        assert_kind_of(Environment.account_class, account)
      end
    end
  end
end
