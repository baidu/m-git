#coding=utf-8

module MGit

  # @!scope [command] add
  # follow git add
  # eg: mgit add .
  #
  class Add < BaseCommand

    # @overload
    #
    def execute(argv)
      Workspace.check_branch_consistency
      Output.puts_start_cmd
      _, error_repos = Workspace.execute_git_cmd_with_repos(argv.cmd, argv.git_opts, all_repos)
      Output.puts_succeed_cmd(argv.absolute_cmd) if error_repos.length == 0
    end

    # @overload
    # @return [Boolean]
    #
    def enable_repo_selection
      true
    end

    # @overload
    #
    def self.description
      "将文件改动加入暂存区。"
    end

    # @overload
    #
    def self.usage
      "mgit add [<git-add-option>] [(--mrepo|--el-mrepo) <repo>...] [--help]"
    end

  end

end
