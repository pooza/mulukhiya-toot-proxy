namespace :mulukhiya do
  namespace :tagging do
    namespace :user do
      desc 'show tags'
      task :list do
        list = []
        Mulukhiya::UserConfigStorage.accounts do |account|
          next unless account.config['/tagging/user_tags'].present?
          list.push('account' => account.acct.to_s, 'tags' => account.config.tags)
        end
        puts list.to_yaml
      end

      task show: [:list]

      desc 'clear tags'
      task :clean do
        Mulukhiya::UserConfigStorage.accounts do |account|
          next unless account.config['/tagging/user_tags'].present?
          account.config.clear_tags
        end
      end

      task clear: [:clean]
    end
  end
end
