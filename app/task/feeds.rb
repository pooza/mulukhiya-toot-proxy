namespace :mulukhiya do
  namespace :tagging do
    namespace :feeds do
      desc 'update feeds'
      task :update do
        if Mulukhiya::Environment.controller_class.feed?
          Mulukhiya::TagAtomFeedRenderer.cache_all(console: true)
        else
          warn "#{Mulukhiya::Environment.controller_class.name} doesn't support feeds."
          exit 1
        end
      end
    end
  end
end
