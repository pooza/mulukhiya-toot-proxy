desc 'test all'
task :test do
  Mulukhiya::TestCase.load((ARGV.first&.split(/[^[:word:],]+/) || [])[1])
end
