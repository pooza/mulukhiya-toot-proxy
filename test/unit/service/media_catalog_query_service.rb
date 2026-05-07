module Mulukhiya
  class MediaCatalogQueryServiceTest < TestCase
    class FakeAttachmentClass
      attr_reader :received_params

      def initialize(result = {items: [], has_next: false})
        @result = result
      end

      def catalog(params)
        @received_params = params
        return @result
      end
    end

    def setup
      @attachment_class = FakeAttachmentClass.new
      @service = MediaCatalogQueryService.new(attachment_class: @attachment_class)
    end

    def test_default_page_is_set_when_cursor_absent
      @service.call({})

      assert_equal(1, @attachment_class.received_params[:page])
    end

    def test_page_is_coerced_to_integer
      @service.call({page: '3'})

      assert_equal(3, @attachment_class.received_params[:page])
    end

    def test_page_is_skipped_when_cursor_present
      @service.call({cursor: 'abc'})

      assert_nil(@attachment_class.received_params[:page])
      assert_equal('abc', @attachment_class.received_params[:cursor])
    end

    def test_only_person_is_normalized_to_zero
      @service.call({only_person: '0'})

      assert_equal(0, @attachment_class.received_params[:only_person])
    end

    def test_only_person_is_normalized_to_one
      @service.call({only_person: '1'})

      assert_equal(1, @attachment_class.received_params[:only_person])
    end

    def test_blank_q_is_dropped_and_no_rule_built
      @service.call({q: ''})

      assert_nil(@attachment_class.received_params[:q])
      assert_nil(@attachment_class.received_params[:rule])
    end

    def test_present_q_builds_search_rule
      @service.call({q: 'キュアホワイト -うどん'})

      assert_kind_of(SearchRule, @attachment_class.received_params[:rule])
      assert_equal('キュアホワイト -うどん', @attachment_class.received_params[:rule].text)
    end

    def test_does_not_mutate_caller_params
      params = {page: '2', q: 'foo'}

      @service.call(params)

      assert_equal({page: '2', q: 'foo'}, params)
    end

    def test_returns_attachment_class_result
      attachment_class = FakeAttachmentClass.new({items: [{id: 1}], has_next: true})
      service = MediaCatalogQueryService.new(attachment_class: attachment_class)

      result = service.call({})

      assert_equal({items: [{id: 1}], has_next: true}, result)
    end
  end
end
