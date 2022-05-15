module Mulukhiya
  class MongoCollectionTest < TestCase
    def disable?
      return true unless Environment.mongo?
      return true unless Mongo.config?
      return super
    end

    def test_aggregate
      assert_kind_of(::Mongo::Collection::View::Aggregation, Meisskey::Status.aggregate('media_catalog'))
      assert_kind_of(::Mongo::Collection::View::Aggregation, Meisskey::Status.aggregate('media_catalog', {q: %(トランキ'ライザーガン)}))
      assert_kind_of(::Mongo::Collection::View::Aggregation, Meisskey::Status.aggregate('media_catalog', {q: %(トランキ"ライザーガン)}))
      assert_kind_of(::Mongo::Collection::View::Aggregation, Meisskey::Status.aggregate('media_catalog', {q: %(トランキ ライザーガン)}))
      assert_kind_of(::Mongo::Collection::View::Aggregation, Meisskey::Status.aggregate('webhook_entries'))
    end
  end
end
