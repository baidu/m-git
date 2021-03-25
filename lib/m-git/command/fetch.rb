#coding=utf-8

module MGit

  # @!scope [command] fetch
  # follow git fetch
  # eg: mgit fetch
  #
  class Fetch < BaseCommand
    def execute(argv)
      Output.puts_start_cmd
      _, error_repos = Workspace.execute_git_cmd_with_repos(argv.cmd, argv.git_opts, all_repos)
      if error_repos.length == 0
        Output.puts_succeed_cmd(argv.absolute_cmd)
        Timer.show_time_consuming_repos
      end
    end

    def enable_repo_selection
      true
    end

    def self.description
      "与远程仓库同步分支引用和数据对象。"
    end

    def self.usage
      "mgit fetch [<git-fetch-option>] [(--mrepo|--el-mrepo) <repo>...] [--help]"
    end
  end

end
