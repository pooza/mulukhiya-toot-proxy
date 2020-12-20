module Mulukhiya
  class AmazonURLHandler < URLHandler
    def rewrite(uri)
      source = AmazonURI.parse(uri.to_s)
      dest = source.clone
      dest.associate_tag = nil
      dest.associate_tag = AmazonService.associate_tag if affiliate?
      dest = dest.shorten
      @status.sub!(source.to_s, dest.to_s)
      sns.account&.config&.update(amazon: {affiliate: nil})
      return dest
    end

    private

    def affiliate?
      return false if sns.account.user_config['/amazon/affiliate'] == false
      return false unless @config['/amazon/affiliate']
      return true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message)
      return true
    end

    def rewritable?(uri)
      uri = AmazonURI.parse(uri.to_s) unless uri.is_a?(AmazonURI)
      return uri.shortenable?
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return false
    end
  end
end
