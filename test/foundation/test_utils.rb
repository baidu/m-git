require_relative '../test_helper'

describe MGit::Utils do

  it "#change_dir(dir)" do
    check_dir = File.expand_path('~')
    cur = Dir.pwd
    MGit::Utils.change_dir(check_dir)
    _(Dir.pwd).must_equal check_dir

    MGit::Utils.change_dir(cur)
    _(Dir.pwd).must_equal cur

    MGit::Utils.change_dir(cur)
    _(Dir.pwd).must_equal cur
  end

  it "#execute_under_dir(dir)" do
    check_dir = File.expand_path('~')
    cur = Dir.pwd
    MGit::Utils.execute_under_dir(check_dir) do
      _(Dir.pwd).must_equal check_dir
    end
    _(Dir.pwd).must_equal cur

    MGit::Utils.execute_under_dir(cur) do
      _(Dir.pwd).must_equal cur
    end
    _(Dir.pwd).must_equal cur
  end

  it "#relative_dir(dir_a, dir_b)" do
    check_a = '/test/a'
    check_a_b = '/test/a/b'
    check_b = '/test/b'

    _(MGit::Utils.relative_dir(check_a, check_b, realpath: false)).must_equal "../a"
    _(MGit::Utils.relative_dir(check_b, check_a, realpath: false)).must_equal "../b"

    _(MGit::Utils.relative_dir(check_a, check_a, realpath: false)).must_equal "."

    _(MGit::Utils.relative_dir(check_a, check_a_b, realpath: false)).must_equal ".."
    _(MGit::Utils.relative_dir(check_b, check_a_b, realpath: false)).must_equal "../../b"
  end

  it "#expand_path(path, base:nil)" do
    # check_a = '/test/a'
    check_a_b = '/test/a/b'
    check_b = '/test/b'

    relative = MGit::Utils.relative_dir(check_b, check_a_b, realpath: false)
    _(MGit::Utils.expand_path(relative, base: check_a_b)).must_equal check_b
  end

  it "#generate_init_cache_path(root)" do

  end

  it "#link(target_path, link_path)" do

  end

  it "#show_clone_info(root, missing_light_repos)" do

  end

  it "#branch_exist_on_remote?(branch, git_url)" do

  end

  it "#url_consist?(url_a, url_b)" do
    url_a = 'https://a.b.cc?s=1'
    url_a_port = 'https://a.b.cc:446'
    url_b = 'http://a.b.cc?s=1'
    url_b_port = 'http://a.b.cc:80'
    url_ab = 'https://a.b.cc?s=1'
    _(MGit::Utils.url_consist?(url_a, url_a_port)).must_equal false
    _(MGit::Utils.url_consist?(url_b, url_ab)).must_equal false
    _(MGit::Utils.url_consist?(url_b, url_b_port)).must_equal true
  end

  it "#normalize_url(url)" do
    url_a = 'https://a.b.cc?s=1'
    url_b = 'http://a.b.cc?s=1'

    _(MGit::Utils.normalize_url(url_a)).must_equal 'https://a.b.cc:443'
    _(MGit::Utils.normalize_url(url_b)).must_equal 'http://a.b.cc:80'
  end
end