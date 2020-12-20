namespace :mulukhiya do
  namespace :tagging do
    namespace :user do
      desc 'show tags'
      task :list do
        list = []
        Mulukhiya::UserConfigStorage.accounts do |account|
          next unless account.user_config['/tagging/user_tags'].present?
          list.push('account' => account.acct.to_s, 'tags' => account.user_config.tags)
        end
        puts list.to_yaml if list.present?
      end

      task show: [:list]

      desc 'clear tags'
      task :clean do
        Mulukhiya::UserConfigStorage.clear_tags
      end

      task clear: [:clean]
    end
  end
end
