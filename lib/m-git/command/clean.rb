#coding=utf-8

module MGit

  # @!scope [command] clean 清除所有仓库中工作区的变更
  # follow git combinatorial command
  # eg: git add . && git reset --hard
  #
  class Clean < BaseCommand

    def execute(argv)

      Output.puts_start_cmd

      # 清除中间态
      OperationProgressManager::PROGRESS_TYPE.each { |type, type_value|
        if OperationProgressManager.is_in_progress?(Workspace.root, type_value)
          Output.puts_processing_message("清除#{type.to_s}中间态...")
          OperationProgressManager.remove_progress(Workspace.root, type_value)
          Output.puts_success_message("清除成功！")
        end
      }

      do_repos = []
      all_repos.each { |repo|
        do_repos.push(repo) if repo.status_checker.status != Repo::Status::GIT_REPO_STATUS[:clean]
      }

      if do_repos.length > 0
        Workspace.check_branch_consistency
        Output.puts_processing_message("正在将改动加入暂存区...")
        _, error_repos1 = Workspace.execute_git_cmd_with_repos('add', '.', do_repos)
        Output.puts_processing_message("正在重置...")
        _, error_repos2 = Workspace.execute_git_cmd_with_repos('reset', '--hard', do_repos)
        Output.puts_succeed_cmd(argv.absolute_cmd) if error_repos1.length + error_repos2.length == 0
      else
        Output.puts_success_message("所有仓库均无改动，无须执行。")
      end

    end

    def validate(argv)
      Foundation.help!("输入非法参数：#{argv.git_opts}。请通过\"mgit #{argv.cmd} --help\"查看用法。") if argv.git_opts.length > 0
    end

    def enable_repo_selection
      true
    end

    def enable_short_basic_option
      true
    end

    def self.description
      "强制清空暂存区和工作区，相当于对指定或所有仓库执行\"git add . && git reset --hard\"操作"
    end

    def self.usage
      "mgit clean [(-m|-e) <repo>...] [-h]"
    end

  end

end
