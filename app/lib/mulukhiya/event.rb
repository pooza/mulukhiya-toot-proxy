module Mulukhiya
  class Event
    attr_reader :label, :params

    def initialize(label, params = {})
      raise "Invalid event '#{label}'" unless Event.syms.member?(label)
      params[:event] = label
      params[:reporter] ||= Reporter.new
      @label = label.to_sym
      @params = params
      @config = Config.instance
    end

    def name
      return label.to_s
    end

    def handlers
      return enum_for(__method__) unless block_given?
      handler_names do |v|
        yield Handler.create(v, params)
      end
    end

    def handler_names(&block)
      return enum_for(__method__) unless block
      @config["/#{Environment.controller_name}/handlers/#{label}"].each(&block)
    end

    def reporter
      return params[:reporter]
    end

    def dispatch(body)
      handlers do |handler|
        raise Ginseng::AuthError, 'Invalid token' unless handler.sns.account
        next if handler.disable?
        thread = Thread.new {handler.send("handle_#{label}".to_sym, body, params)}
        unless thread.join(handler.timeout)
          handler.errors.push(message: 'execution expired', timeout: "#{handler.timeout}s")
        end
        break if handler.prepared?
      rescue RestClient::Exception, HTTParty::Error => e
        handler.errors.push(class: e.class.to_s, message: e.message)
      ensure
        reporter.push(handler)
      end
      return reporter
    end

    def self.all
      return enum_for(__method__) unless block_given?
      syms.each do |sym|
        yield Event.new(sym)
      end
    end

    def self.syms
      return Environment.controller_class.event_syms
    end
  end
end
