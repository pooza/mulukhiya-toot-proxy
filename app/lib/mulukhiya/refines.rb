module Mulukhiya
  module Refines
    class ::String
      def encrypt
        return Crypt.new.encrypt(self)
      end

      def decrypt
        return Crypt.new.decrypt(self)
      end

      def blockquote(prompt = '>')
        return dup.each_line.map {|l| "#{prompt} #{l.chomp}"}.join("\n")
      end
    end

    class ::Hash
      def to_yaml
        return YAML.dump(deep_stringify_keys)
      end
    end

    class ::Array
      def to_yaml
        return YAML.dump(deep_stringify_keys)
      end
    end

    class ::Set
      def to_yaml
        return YAML.dump(to_a.deep_stringify_keys)
      end
    end

    class ::StandardError
      def log(values = {})
        return if is_a?(Sequel::Error) && !Environment.dbms_class&.config?
        Logger.new.error({error: self}.merge(values))
        warn(to_h.to_yaml) if Environment.test? && Environment.development?
      end

      def alert(values = {})
        log(values)
        # Sentry 到達不能 (DNS 障害・rate limit 等) で capture_exception 自体が例外を
        # 投げると、上位の rescue がさらに alert/log を呼ぶ経路で再帰的 500 (#4317
        # の元症状) に逆戻りする。Sinatra error handler だけでなく api_controller
        # 各 rescue 経路も保護するため、ここで集約防御する。
        Sentry.capture_exception(self) rescue nil if Sentry.initialized?
        return Event.new(:alert).dispatch(self)
      end

      def source_class
        return self.class
      end
    end
  end
end
