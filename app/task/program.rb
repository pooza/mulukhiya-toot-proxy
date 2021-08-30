namespace :mulukhiya do
  namespace :program do
    desc 'update programs'
    task :update do
      Mulukhiya::ProgramUpdateWorker.new.perform
    end

    desc 'show programs'
    task :show do
      puts Mulukhiya::Program.instance.to_yaml
    end
  end
end
