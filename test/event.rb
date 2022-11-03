module Mulukhiya
  class EventTest < TestCase
    def setup
      @event = Event.new(:pre_toot)
    end

    def test_all
      Event.all do |event|
        assert_kind_of(Event, event)
      end
    end

    def test_handlers
      @event.handlers do |handler|
        assert_kind_of(Handler, handler)
      end
    end

    def all_handlers
      @event.handlers do |handler|
        assert_kind_of(Handler, handler)
        assert_boolean(handler.disable?)
        assert_boolean(handler.verbose?)
      end
    end

    def test_dispatch
      @event.dispatch(
        status_field => '#nowplaying https://open.spotify.com/track/3h5LpK0cYVoZgkU1Gukedq',
        visibility_field => controller_class.visibility_name(:private),
      )

      assert(@event.reporter.tags.member?('宮本佳那子'))
      assert(@event.reporter.tags.member?('福山沙織'))
      assert(@event.reporter.tags.member?('井上由貴'))
    end

    def test_syms
      assert_kind_of(Set, Event.syms)
      Event.syms.each do |sym|
        assert_kind_of(Symbol, sym)
      end
    end
  end
end
