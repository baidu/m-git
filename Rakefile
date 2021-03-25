
require "bundler/gem_tasks"
task :default => :test


require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = 'test/**/test_*.rb'
  t.verbose = true
end