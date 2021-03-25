#coding=utf-8

module MGit
  module Template

    PRE_CUSTOMIZED_PUSH_HOOK_TEMPLATE = '
#coding=utf-8

module MGitTemplate

  class PrePushHook

    # hook接口，用于接受push指令执行后的数据
    #
    # @param cmd [String] 本次执行指令
    #
    # @param opts [String] 本次执行指令参数
    #
    # @param mgit_root [String] mgit根目录
    #
    # @param exec_repos [Array<Manifest::LightRepo>] 本次执行指令的LightRepo数组
    #
    def self.run(cmd, opts, mgit_root, exec_repos)

    end

  end

end
  '
  end
end
