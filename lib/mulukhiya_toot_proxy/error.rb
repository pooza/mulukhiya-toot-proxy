module MulukhiyaTootProxy
  class Error < StandardError
    attr_accessor :source_error

    def status
      return 500
    end

    def to_h
      h = {class: self.class.name, message: message}
      h[:source_class] = @source_error if @source_error
      h[:backtrace] = backtrace[0..5] if backtrace
      return h
    end

    def self.create(src)
      return src if src.is_a?(Error)
      dest = new(src.message)
      dest.source_error = src.class.name
      dest.set_backtrace(src.backtrace)
      return dest
    end
  end
end
