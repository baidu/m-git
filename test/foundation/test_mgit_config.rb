

require_relative '../test_helper'


describe MGit::MGitConfig do

  STUB_CONFIG = {
      'managegit' => true,
      'maxconcurrentcount' => 4,
      'savecache' => true
  }

  def __stub_config_env
    MGit::MGitConfig.stub :__load_file, [STUB_CONFIG, nil] do
      yield if block_given?
    end
  end

  def __stub_write_config
    MGit::MGitConfig.stub :write_to_file, nil do
      yield if block_given?
    end
  end

  it "#query(root)" do
    __stub_config_env do
      MGit::MGitConfig.query('') do |cfg_hash|
        _(cfg_hash['managegit']).must_equal true
        _(cfg_hash['maxconcurrentcount']).must_equal 4
        _(cfg_hash['none_key']).must_be_nil
      end
    end
  end

  it "#query_with_key(root, key_symbol)" do
    __stub_config_env do
      query_value = MGit::MGitConfig.query_with_key('', 'managegit')
      _(query_value).must_equal true

      query_value = MGit::MGitConfig.query_with_key('', 'no-managegit')
      _(query_value).must_be_nil
    end
  end

  it "#update(root)" do
    __stub_config_env do
      __stub_write_config do
        MGit::MGitConfig.update('') do |cfg_hash|
          cfg_hash['managegit'] = false
        end
        query_value = MGit::MGitConfig.query_with_key('', 'managegit')
        _(query_value).must_equal false

        MGit::MGitConfig.update('') do |cfg_hash|
          cfg_hash['managegit'] = true
        end

        query_value = MGit::MGitConfig.query_with_key('', 'managegit')
        _(query_value).must_equal true
      end
    end
  end

  it "#dump_config(root)" do

  end

  it "#to_suitable_value_for_key(root, key, value)" do
    __stub_config_env do
      to_value = MGit::MGitConfig.to_suitable_value_for_key('', 'managegit', 1)
      _(to_value).must_be_nil

      to_value = MGit::MGitConfig.to_suitable_value_for_key('', 'managegit', "false")
      _(to_value).must_equal false
    end
  end

  it "#write_to_file(root, content)" do

  end
end
