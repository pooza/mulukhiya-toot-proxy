module Mulukhiya
  class Event
    include Package

    attr_reader :label, :params

    def initialize(label, params = {})
      raise "Invalid event '#{label}'" unless Event.syms.member?(label)
      params[:event] = label
      params[:reporter] ||= Reporter.new
      @label = label.to_sym
      @params = params
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
      resolve_pipeline
        .reject {|name| config.disable?(Handler.create(name))}
        .each(&block)
    end

    def all_handlers(&block)
      return enum_for(__method__) unless block
      all_handler_names.filter_map {|v| Handler.create(v, params)}.each(&block)
    end

    def all_handler_names(&block)
      return enum_for(__method__) unless block
      resolve_pipeline
        .sort_by(&:underscore)
        .each(&block)
    end

    def count
      return handler_names.count
    end

    def reporter
      return params[:reporter]
    end

    def method
      return :"handle_#{label}"
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
      base_events = config.keys('/handler/pipeline/base') rescue []
      sns_events = config.keys("/handler/pipeline/#{Environment.controller_name}") rescue []
      return (base_events + sns_events).to_set(&:to_sym)
    end

    private

    def resolve_pipeline
      base = config["/handler/pipeline/base/#{label}"] rescue nil
      sns_config = config["/handler/pipeline/#{Environment.controller_name}/#{label}"] rescue nil
      return base if base.is_a?(Array) && sns_config.nil?
      return sns_config if sns_config.is_a?(Array)
      if base.is_a?(Array) && sns_config.is_a?(Hash)
        result = base.dup
        Array(sns_config['exclude']).each {|h| result.delete(h)}
        return result
      end
      return []
    end
  end
end
