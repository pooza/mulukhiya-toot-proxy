namespace :mulukhiya do
  namespace :tagging do
    namespace :feed do
      desc 'update feed'
      task :update do
        if Mulukhiya::Environment.controller_class.tag_feed?
          Mulukhiya::TagAtomFeedRenderer.cache_all
          Mulukhiya::TagAtomFeedRenderer.all do |renderer|
            puts "updated: ##{renderer.tag} #{renderer.path}"
          end
        else
          warn "#{Mulukhiya::Environment.controller_class.name} doesn't support tag feeds."
          exit 1
        end
      end
    end
  end
end
