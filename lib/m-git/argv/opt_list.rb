#coding=utf-8

module MGit
  class ARGV
    # 参数对象列表
    class OptList

      # [Array<ARGV::Opt>] 参数对象数组
      attr_accessor :opts

      # attr_reader :valid_opts

      def initialize(opts)
        @opts = opts
      end

      def valid_opts
        @opts.select { |e| !e.empty? }
      end

      # 获取某个参数对象
      #
      # @param key [String] 参数名，如‘--key’
      #
      # @return [ARGV::Opt] 参数对象，若参数未设置过则返回nil
      #
      def opt(key)
        valid_opts.find { |e| (e.key == key || e.short_key == key) }
      end
      alias_method :opt_with, :opt

      # 判断参数是否设置过值
      #
      # @return [Boolean] 参数是否设置过值
      #
      def did_set_opt?(key)
        !opt(key).nil?
      end

      ## all opts ###

      # 返回某个注册过的参数对象
      #
      # @param key [String] 参数名，如‘--key’
      #
      # @return [ARGV::Opt] 参数对象，无论参数是否设置过，只要注册过就返回
      #
      def registered_opt(key)
        @opts.find { |e| (e.key == key || e.short_key == key) }
      end

      # 判断参数是否注册过
      #
      # @return [Boolean] 参数是否注册过
      #
      def did_register_opt?(key)
        !registered_opt(key).nil?
      end

      # 将参数根据优先级排序（逆序）后返回
      #
      # @return [Array<ARGV::Opt>] 包含参数对象的数组
      #
      def opts_ordered_by_priority
        # 按照优先级进行降序排序
        opts.sort_by { |e| e.priority }.reverse
      end
    end
  end

end
