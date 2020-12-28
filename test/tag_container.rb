module Mulukhiya
  class TagContainerTest < TestCase
    def setup
      config['/tagging/default_tags'] = ['美食丼', 'b-shock-don']
    end

    def test_default_tags
      assert_equal(TagContainer.default_tags, ['#美食丼', '#b_shock_don'])
    end

    def test_futured_tag_bases
      TagContainer.futured_tag_bases.each do |tag|
        assert_kind_of(String, tag)
      end
    end

    def test_field_tag_bases
      TagContainer.field_tag_bases.each do |tag|
        assert_kind_of(String, tag)
      end
    end
  end
end
