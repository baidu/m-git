require_relative 'test_helper'

describe MGit::ARGV do

  let(:input_argv) {
    cmd = "checkout -b branch_name --mrepo boxapp BBAAccount --command test".split(" ")
    argv = MGit::ARGV::Parser.parse(cmd)

    opts = []
    opts << MGit::ARGV::Opt.new('--mrepo', info: 'first one')
    opts << MGit::ARGV::Opt.new('--command')
    opts << MGit::ARGV::Opt.new('--other_command', info: 'last one')
    argv.register_opts(opts)
    argv.resolve!
    argv
  }

  it "#update_opt(key, value)" do

    opt = input_argv.opt('--command')
    _(opt.value).must_equal ['test']

    input_argv.update_opt('--command', 'test1')
    _(opt.value).must_equal 'test1'

    input_argv.update_opt('--command', ['test'])
  end

  it "#opt(key)" do
    opt = input_argv.opt('--command')
    _(opt.value).must_equal ['test']

    opt = input_argv.opt('--mrepo')
    _(opt.value).must_equal ['boxapp', 'BBAAccount']
  end

  it "#info(key)" do
    _(input_argv.info('--mrepo')).must_equal "first one"
    _(input_argv.info('--other_command')).must_equal "last one"
  end

  it "#git_opts(raw: true)" do
    _(input_argv.git_opts).must_equal "-b \"branch_name\""
    _(input_argv.git_opts(raw: false).first).must_equal ['-b', '"branch_name"']
  end

  it "#is_option?(opt_str)" do
    _(input_argv.is_option?('--s')).must_equal true
    _(input_argv.is_option?('--ss')).must_equal true
    _(input_argv.is_option?('-s')).must_equal true
    _(input_argv.is_option?('_s')).must_equal false
    _(input_argv.is_option?('-ss')).must_equal true
  end

  describe "stub_test" do

    it "optlist_stub" do
      # stub_obj = MGit::ARGV::Opt.new('--command')

      stub_block = Proc.new do |key|
        MGit::ARGV::Opt.new(key, info: "#{key}_info")
      end
      input_argv.opt_list.stub :opt, stub_block do |mm|
        _(mm.opt('--s').info).must_equal "--s_info"
        _(input_argv.opt('-super').info).must_equal "-super_info"
      end
      _(input_argv.opt('--s')).must_be_nil
    end

    it "optlist_stub_object" do
      stub_obj = MGit::ARGV::Opt.new('--command')
      input_argv.opt_list.stub :opt, stub_obj do
        _(input_argv.opt('--s').key).must_equal "--command"
        _(input_argv.opt('-super').key).must_equal "--command"
      end
    end
  end

  describe "mock_test" do
    it "optlist_mock" do
      MGit::ARGV.define_method(:set_opt_list) do |list|
        @opt_list = list
      end
      assert_nil input_argv.opt('--none')

      opt_list = Minitest::Mock.new
      mock_obj = MGit::ARGV::Opt.new('--default')
      opt_list.expect :opt, mock_obj,  ['--none']
      input_argv.set_opt_list opt_list
      _(input_argv.opt('--none').key).must_equal '--default'
    ensure
      MGit::ARGV.undef_method(:set_opt_list)
    end
  end

end