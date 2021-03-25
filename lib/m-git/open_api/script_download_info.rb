#coding=utf-8
module MGit
  class OpenApi

    module DownloadResult
      SUCCESS = 0
      FAIL = 1
      EXIST = 2
    end

    class ScriptDownloadInfo

      # [String] 下载仓库名
      attr_reader :repo_name

      # [String] 下载仓库本地地址
      attr_reader :repo_path

      # [OpenApi::DOWNLOAD_RESULT] 下载结果
      attr_reader :result

      # [String] 执行输出，若出错，该变量保存出错信息，可能为nil
      attr_reader :output

      # [Float] 当前仓库在整个下载任务中所处进度（如10个任务，当前第5个下载完，则progress=0.5），并非单仓库下载进度。
      attr_reader :progress

      def initialize(repo_name, repo_path, result, output, progress)
        @repo_name = repo_name
        @repo_path = repo_path
        @result = result
        @output = output
        @progress = progress
      end
    end
  end
end
