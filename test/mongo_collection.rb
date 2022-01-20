module Mulukhiya
  class MongoCollectionTest < TestCase
    def test_aggregate
      assert_kind_of(::Mongo::Collection::View::Aggregation, Meisskey::Status.aggregate('media_catalog'))
      assert_kind_of(::Mongo::Collection::View::Aggregation, Meisskey::Status.aggregate('media_catalog', {q: %(トランキ'ライザーガン)}))
      assert_kind_of(::Mongo::Collection::View::Aggregation, Meisskey::Status.aggregate('media_catalog', {q: %(トランキ"ライザーガン)}))
      assert_kind_of(::Mongo::Collection::View::Aggregation, Meisskey::Status.aggregate('media_catalog', {q: %(トランキ ライザーガン)}))
      assert_kind_of(::Mongo::Collection::View::Aggregation, Meisskey::Status.aggregate('webhook_entries'))
    end
  end
end
