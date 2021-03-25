
require 'minitest/autorun'
require 'minitest/reporters'
MiniTest::Reporters.use! Minitest::Reporters::SpecReporter.new
#

# syntax: http://www.mattsears.com/articles/2011/12/10/minitest-quick-reference/
#

Dir.glob(File.join(File.dirname(__FILE__), %w(.. lib *.rb ))).each do |file|
  require file
end

module MGitTest
  module FileProvider
    TEST_ROOT = File.dirname(__FILE__)

    EXAMPLE_DIR = File.join(TEST_ROOT, 'example')

    EXAMPLE_GIT_DIR = File.join(EXAMPLE_DIR, 'git_repo')

    EXAMPLE_NOT_GIT_DIR = File.join(EXAMPLE_DIR, 'not_git_repo')

    FILE_IN_GIT = File.join(EXAMPLE_GIT_DIR, '.git/a')

    EXAMPLE_IN_GIT_FILE = File.join(EXAMPLE_DIR, 'deep_dir/a')
  end
end
