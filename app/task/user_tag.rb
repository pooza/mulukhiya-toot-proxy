namespace :mulukhiya do
  namespace :tagging do
    namespace :user do
      desc 'show tags'
      task :list do
        Mulukhiya::UserConfigStorage.accounts do |account|
          next unless account.config['/tags'].present?
          puts YAML.dump(account: account.acct.to_s, tags: account.config['/tags'])
        end
      end

      desc 'clear tags'
      task :clean do
        Mulukhiya::UserConfigStorage.accounts do |account|
          next unless account.config['/tags'].present?
          account.config.update(tags: nil)
        end
      end

      task clear: [:clean]
    end
  end
end
