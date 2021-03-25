#coding=utf-8

module MGit
  module Template
    POST_DOWNLOAD_HOOK_TEMPLATE = '
#coding=utf-8

module MGitTemplate

  class PostDownloadHook

    # hook接口，单个仓库下载完成后调用
    #
    # @param name [String] 下载仓库名
    #
    # @param path [String] 下载仓库的本地绝对路径
    #
    # @return [Boolean] 是否改动仓库HEAD
    #
    def self.run(name, path)

    end

  end

end
  '
  end
end
