

require_relative '../test_helper'


describe Dir do

  # before do
  #   @git_dir  = MiniTest::Mock.new
  # end

  it "#is_git_repo?(path)" do
    mock_git_path = '/stub/.git'

    stub_block = lambda do |path|
      return true if path == '/stub'
      mock_git_path == path
    end
    File.stub :directory?, stub_block do
      _(Dir.is_git_repo?('/stub')).must_equal true
      _(Dir.is_git_repo?('/other')).must_equal false
    end
  end

  it "#is_in_git_repo?(path)" do
    mock_git_path = '/stub/.git'

    stub_block = lambda do |path|
      return true if path == '/stub' || path == '/stub/sub_dir'
      mock_git_path == path
    end
    File.stub :directory?, stub_block do
      _(Dir.is_in_git_repo?('/stub/sub_dir')).must_equal true
      _(Dir.is_in_git_repo?('/other/sub_dir')).must_equal false
    end
  end

end