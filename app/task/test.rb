module Mulukhiya
  extend Rake::DSL

  desc 'test all'
  task :test do
    TestCase.load((ARGV.first&.split(/[^[:word:],]+/) || [])[1])
  end
end
