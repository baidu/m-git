#coding=utf-8

module MGit

  class ARGV
    # 单个选项, 如‘--k1=v1 --k2 v2 v3 --flag’
    # '--k1=v1'     key: '--k1', value: 'v1'
    # '--k2 v2 v3'  key: '--k2', value: ['v2', 'v3']
    # '--flag'      key: '--flag', value: true
    class Opt
      attr_reader   :key
      attr_accessor :value
      attr_accessor :short_key        # 短参数格式，如’--command’对应的‘-c’
      attr_accessor :priority         # 参数解析优先级
      attr_accessor :info             # 参数说明

      # @!attribute value值类型
      # :array  :string  :boolean
      attr_accessor :value_type

      def initialize(key, default:nil, short_key:nil, priority:-1, info:nil, type: :array)
        raise("初始化Opt选项必须有key") if key.nil?
        @key, @value, @short_key, @priority, @info = key, default, short_key, priority, info
        @value_type = type
      end

      def empty?
        value.nil? || value == '' || value == [] || value == false
      end

      def validate?
        return false if empty?
        value.is_a?(value_type)
      end
    end
  end

end
