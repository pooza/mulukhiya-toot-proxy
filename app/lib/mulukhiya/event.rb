module Mulukhiya
  class Event
    include Package
    attr_reader :label, :params

    def initialize(label, params = {})
      raise "Invalid event '#{label}'" unless Event.syms.member?(label)
      params[:event] = label
      params[:reporter] ||= Reporter.new
      @label = label.to_sym
      @params = (params || {}).deep_symbolize_keys
    end

    def name
      return label.to_s
    end

    def handlers(&block)
      return enum_for(__method__) unless block
      handler_names.filter_map {|v| Handler.create(v, params)}.each(&block)
    end

    def handler_names(&block)
      return enum_for(__method__) unless block
      config["/#{Environment.controller_name}/handlers/#{label}"]
        .reject {|name| config.disable?(Handler.create(name))}
        .each(&block)
    end

    def count
      return handler_names.count
    end

    def reporter
      return params[:reporter]
    end

    def method
      return "handle_#{label}".to_sym
    end

    def dispatch(payload)
      handlers do |handler|
        next if handler.disable?
        unless Thread.new {handler.send(method, payload, params)}.join(handler.timeout)
          handler.errors.push(message: 'timeout', timeout: "#{handler.timeout}s")
        end
        break if handler.break?
      rescue => e
        handler.errors.push(class: e.class.to_s, message: e.message)
      ensure
        reporter.push(handler)
      end
      return reporter
    end

    def self.all(&block)
      return enum_for(__method__) unless block
      syms.map {|v| new(v)}.each(&block)
    end

    def self.syms
      return config.keys("/#{Environment.controller_name}/handlers").map(&:to_sym).to_set
    end
  end
end
