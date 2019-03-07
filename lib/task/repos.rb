namespace :repos do
  desc 'alias of bundle:update'
  task update: ['bundle:update']

  desc 'alias of bundle:check'
  task check: ['bundle:check']
end
