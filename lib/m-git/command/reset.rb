#coding=utf-8

module MGit

  # @!scope 类似 git reset
  #
  class Reset < BaseCommand

    def execute(argv)
      Workspace.check_branch_consistency

      Output.puts_start_cmd
      _, error_repos = Workspace.execute_git_cmd_with_repos(argv.cmd, argv.git_opts, all_repos)
      Output.puts_succeed_cmd(argv.absolute_cmd) if error_repos.length == 0
    end

    def enable_repo_selection
      true
    end

    def self.description
      "将当前HEAD指针还原到指定状态。"
    end

    def self.usage
      "mgit reset [<git-reset-option>] [(--mrepo|--el-mrepo) <repo>...] [--help]"
    end

  end

end
