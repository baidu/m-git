


require_relative '../test_helper'


describe MGit::ARGV::OptList do

  let(:list) {
    arr = []
    opt = MGit::ARGV::Opt.new('--aa', short_key: '-a', info: "first", priority: 1)
    opt.value = true
    arr << opt

    opt = MGit::ARGV::Opt.new('--cc', short_key: '-c', info: "third", priority: 3)
    arr << opt

    opt = MGit::ARGV::Opt.new('--bb', short_key: '-b', info: "second", priority: 2)
    opt.value = true
    arr << opt


    MGit::ARGV::OptList.new(arr)
  }

  it "#opt(key)" do
    _(list.opt('--aa').info).must_equal "first"

    _(list.opt('-a').info).must_equal "first"

    _(list.opt('--bb').info).must_equal "second"

    _(list.opt('-b').info).must_equal "second"

    _(list.opt('-c')).must_be_nil
    _{list.opt('--cc').info}.must_raise NoMethodError
  end

  it "#registered_opt(key)" do
    _(list.registered_opt('--cc').info).must_equal "third"
    _(list.registered_opt('--d')).must_be_nil
  end

  it "#did_set_opt?(key)" do
    _(list.did_set_opt?('-b')).must_equal true
    _(list.did_set_opt?('-c')).must_equal false # no value
    _(list.did_set_opt?('--d')).must_equal false
  end

  it "#opts_ordered_by_priority" do
    opts = list.opts_ordered_by_priority
    _(opts.first.info).must_equal "third"
    _(opts.last.info).must_equal "first"
  end
end