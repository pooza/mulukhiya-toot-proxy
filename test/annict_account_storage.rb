module Mulukhiya
  class AnnictAccountStorageTest < TestCase
    def disable?
      return true unless controller_class.annict?
      return true unless AnnictService.config?
      return true unless (account.annict rescue nil)
      return super
    end

    def test_accounts
      return unless account_class
      AnnictAccountStorage.accounts do |account|
        assert_kind_of(account_class, account)
      end
    end
  end
end
