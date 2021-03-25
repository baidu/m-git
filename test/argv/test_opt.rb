

require_relative '../test_helper'


describe MGit::ARGV::Opt do

  it "opt key cant be nil" do
    _{MGit::ARGV::Opt.new(nil)}.must_raise RuntimeError
  end

  describe "Check Empty" do
    let(:entity) {
      MGit::ARGV::Opt.new('key')
    }
    it "is empty" do
      _(entity.empty?).must_equal true
    end

    it "is not empty" do
      entity.value = 'a'
      _(entity.empty?).must_equal false

      entity.value = true
      _(entity.empty?).must_equal false

      entity.value = false
      _(entity.empty?).must_equal true

      entity.value = nil
      _(entity.empty?).must_equal true
    end

  end

end