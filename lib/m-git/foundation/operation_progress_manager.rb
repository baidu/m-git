#coding=utf-8

module MGit
  # 本类用于缓存/加载操作中间态
  class OperationProgressContext

    # 现场信息关键字段
    CONTEXT_CMD = 'cmd'
    CONTEXT_OPTS = 'opts'
    CONTEXT_BRANCH = 'branch'
    CONTEXT_REPOS = 'repos'
    CONTEXT_OTHER = 'other'

    attr_accessor :type     # String: 本次进入中间态的操作类型，可自定义，如'merge_in_progress','rebase_in_progress'等。该字段用于索引缓存的中间态信息，需要唯一。
    attr_accessor :cmd      # String: 本次执行指令，如'merge'，'checkout'等
    attr_accessor :opts     # String: 本次执行参数，如'--no-ff'，'--ff'等
    attr_accessor :branch   # String: 仓库当前分支
    attr_accessor :repos    # [String]: 本次执行哪些仓库的名称数组
    attr_accessor :other    # Object: 其他信息，可自定义

    def initialize(type)
      self.type = type
      self.other = {}
    end

    # 将中间态对象序列化为Hash
    def serialize
      return {
          CONTEXT_CMD         => self.cmd,
          CONTEXT_OPTS        => self.opts,
          CONTEXT_BRANCH      => self.branch,
          CONTEXT_REPOS       => self.repos,
          CONTEXT_OTHER       => self.other
      }
    end

    # 反序列化
    #
    # @param dict [Hash] 中间态Hash
    #
    def deserialize(dict)
      self.cmd = dict[CONTEXT_CMD]
      self.opts = dict[CONTEXT_OPTS]
      self.branch = dict[CONTEXT_BRANCH]
      self.repos = dict[CONTEXT_REPOS]
      self.other = dict[CONTEXT_OTHER]
    end

    # 校验中间态是否合法，仓库可缺省，若缺省则表示所有仓库
    #
    # @return [Boolean] 是否合法
    #
    def validate?
      return !self.cmd.nil? && !self.opts.nil? && !self.branch.nil?
    end
  end

  class OperationProgressManager

    PROGRESS_TYPE = {
        :merge  =>  'merge_in_progress',
        :rebase =>  'rebase_in_progress',
        :pull   =>  'pull_in_progress'
    }.freeze

    class << self

      # 进入中间态
      #
      # @param root [String] 多仓库根目录
      #
      # @param context [OperationProgressContext] 中间态对象
      #
      def trap_into_progress(root, context)
        begin
          MGitConfig.update(root) { |config|
            config[context.type] = context.serialize
          }
        rescue Error => e
          Output.puts_fail_message(e.msg)
        end
      end

      # 删除中间态
      #
      # @param root [String] 多仓库根目录
      #
      # @param type [String] 自定义Key值，用于索引中间态信息
      #
      def remove_progress(root, type)
        begin
          MGitConfig.update(root) { |config|
            config.delete(type)
          }
        rescue Error => e
          Output.puts_fail_message(e.msg)
        end
      end

      # 是否处于中间态中
      def is_in_progress?(root, type)
        is_in_progress = false
        begin
          MGitConfig.query(root) { |config|
            is_in_progress = !config[type].nil?
          }
        rescue Error => e
          Output.puts_fail_message(e.msg)
        end
        return is_in_progress
      end

      # 加载中间态上下文
      #
      # @param root [String] 多仓库根目录
      #
      # @param type [String] 自定义Key值，用于索引中间态信息
      #
      # @return [OperationProgressContext，String] 中间态对象；错误信息
      #
      def load_context(root, type)
        context = nil
        error = nil
        begin
          MGitConfig.query(root) { |config|
            dict = config[type]
            context = OperationProgressContext.new(type)
            context.deserialize(dict)
          }
        rescue Error => e
          Output.puts_fail_message(e.msg)
          error = e.msg
        end
        return context, error
      end

    end
  end
end
