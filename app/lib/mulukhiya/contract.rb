require 'dry-validation'

module Mulukhiya
  class Contract < Dry::Validation::Contract
    config.messages.default_locale = :ja
    config.messages.backend = :yaml
    config.messages.load_paths << File.join(Environment.dir, 'config/contract.yaml')

    def exec(params)
      return call(params).errors.to_h
    end
  end
end
