namespace :config do
  desc 'lint local config'
  task :lint do
    if errors.present?
      puts YAML.dump(errors)
      exit 1
    else
      puts 'OK'
    end
  end

  def errors
    @errors ||= contract.call(config).errors.to_h
    return @errors
  end

  def config
    return Mulukhiya::Config.instance.raw['local']
  end

  def contract
    return Mulukhiya::LocalConfigContract.new
  end
end
