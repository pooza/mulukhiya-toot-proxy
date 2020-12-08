namespace :mulukhiya do
  namespace :tagging do
    namespace :user do
      desc 'show tags'
      task :list do
        Mulukhiya::UserConfigStorage.accounts do |account|
          next unless account.config['/tagging/user_tags'].present?
          puts YAML.dump(account: account.acct.to_s, tags: account.config['/tagging/user_tags'])
        end
      end

      desc 'clear tags'
      task :clean do
        Mulukhiya::UserConfigStorage.accounts do |account|
          next unless account.config['/tagging/user_tags'].present?
          account.config.update(tags: nil)
        end
      end

      task clear: [:clean]
    end
  end
end
