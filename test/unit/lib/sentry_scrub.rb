module Mulukhiya
  class SentryScrubTest < TestCase
    def build_event(message)
      config = Sentry::Configuration.new
      event = Sentry::ErrorEvent.new(configuration: config)
      exc = RuntimeError.new(message)
      exc.set_backtrace(caller)
      mechanism = Sentry::Mechanism.new(type: 'generic', handled: true)
      event.add_exception_interface(exc, mechanism: mechanism)
      return event
    end

    def test_scrub_token
      event = build_event('Token abc123XYZ456defGHI789jkl failed')
      result = Mulukhiya.scrub_sentry_event(event, {})

      assert_not_match(/abc123XYZ456defGHI789jkl/, result.exception.values.first.value)
      assert_match(/\[FILTERED\]/, result.exception.values.first.value)
    end

    def test_scrub_path
      event = build_event('Error at /home/mastodon/mulukhiya-toot-proxy/app/lib/foo.rb')
      result = Mulukhiya.scrub_sentry_event(event, {})

      assert_not_match(%r{/home/mastodon}, result.exception.values.first.value)
    end

    def test_scrub_preserves_short_strings
      event = build_event('Something went wrong')
      result = Mulukhiya.scrub_sentry_event(event, {})

      assert_match(/Something went wrong/, result.exception.values.first.value)
    end

    def test_scrub_no_exception
      config = Sentry::Configuration.new
      event = Sentry::ErrorEvent.new(configuration: config)
      result = Mulukhiya.scrub_sentry_event(event, {})

      assert_not_nil(result)
    end
  end
end
