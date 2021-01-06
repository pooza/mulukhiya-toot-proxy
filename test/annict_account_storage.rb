module Mulukhiya
  class AnnictAccountStorageTest < TestCase
    def test_accounts
      return unless account_class
      AnnictAccountStorage.accounts do |account|
        assert_kind_of(account_class, account)
      end
    end
  end
end
