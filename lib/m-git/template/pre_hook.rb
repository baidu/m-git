#coding=utf-8

module MGit
  module Template
    PRE_CUSTOMIZED_HOOK_TEMPLATE = '
#coding=utf-8

module MGitTemplate

  class PreHook

    # hook接口，用于接受本次指令执行前的数据
    #
    # @param cmd [String] 本次执行指令
    #
    # @param opts [String] 本次执行指令参数
    #
    # @param mgit_root [String] mgit根目录
    #
    def self.run(cmd, opts, mgit_root)

    end

  end

end
  '
  end
end
