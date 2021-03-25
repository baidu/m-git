

require_relative '../test_helper'


describe MGit::ARGV::Parser do

  let(:input_argv) {
    cmd = "checkout -b branch_name --mrepo boxapp BBAAccount --command test".split(" ")
    MGit::ARGV::Parser.parse(cmd)
  }


  # # 指令名，如："mgit checkout -b branch_name"的"checkout"
  # attr_reader :cmd
  #
  # # 所有参数，如："mgit checkout -b branch_name"的"checkout -b branch_name"
  # attr_reader :pure_opts
  #
  # # 完整指令，如："mgit checkout -b branch_name"
  # attr_reader :absolute_cmd
  #
  # # 本次传入的mgit指令中自定义的部分，如："mgit checkout -b branch_name --mrepo boxapp BBAAccount --command test"的"[[--mrepo boxapp BBAAccount],[--command test]]"
  # attr_reader :raw_opts
  #
  # # 本次传入的mgit指令中git透传的部分，如："mgit checkout -b branch_name --mrepo boxapp BBAAccount"的"[[-b branch_name]]"
  # # has define method git_opts
  #
  # # 所有已注册的参数列表
  # attr_reader :opt_list
  #
  describe "#parse(argv)" do
    it "#cmd" do
      _(input_argv.cmd).must_equal "checkout"
    end

    it "#pure_opts" do
      _(input_argv.pure_opts).must_equal "-b branch_name --mrepo boxapp BBAAccount --command test"
    end

    it "#absolute_cmd" do
      _(input_argv.absolute_cmd).must_equal "checkout -b branch_name --mrepo boxapp BBAAccount --command test"
    end

    it "#raw_opts" do
      _(input_argv.raw_opts.first.join(" ")).must_equal "-b branch_name"
      _(input_argv.raw_opts.first.count).must_equal 2

      _(input_argv.raw_opts[1].join(" ")).must_equal "--mrepo boxapp BBAAccount"
      _(input_argv.raw_opts[1].count).must_equal 3

      _(input_argv.raw_opts.last.join(" ")).must_equal "--command test"
      _(input_argv.raw_opts.last.count).must_equal 2
    end

  end

end