namespace :mulukhiya do
  namespace :program do
    desc 'update programs'
    task :update do
      program.update
      puts "#{program.count} programs"
    end

    desc 'show programs'
    task :show do
      puts program.to_yaml
    end

    def program
      return Mulukhiya::Program.instance
    end
  end
end
