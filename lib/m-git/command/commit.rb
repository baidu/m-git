#coding=utf-8

module MGit

  # @!scope [command] commit
  # follow git commit
  # eg: mgit commit -m 'Just for fun'
  #
  class Commit < BaseCommand

    private def validate(argv)
      super
      # 禁用--amend
      if argv.git_opts.include?('--amend')
        Output.puts_fail_message("MGit不支持\"--amend\"操作,请重试。")
        Output.puts_cancel_message
        exit
      end
    end

    def execute(argv)
      Workspace.check_branch_consistency

      Output.puts_start_cmd

      do_repos = []
      remind_repos = []
      do_nothing_repos = []

      Output.puts_processing_message("检查各仓库状态...")
      Workspace.serial_enumerate_with_progress(all_repos) { |repo|
        if repo.status_checker.status == Repo::Status::GIT_REPO_STATUS[:dirty]
          index_dirty_mask = Repo::Status::GIT_REPO_STATUS_DIRTY_ZONE[:index]
          # 仅在暂存区有未提交的改动时执行
          if repo.status_checker.dirty_zone & index_dirty_mask == index_dirty_mask
            do_repos.push(repo)
          else
            remind_repos.push(repo.name)
          end
        else
          do_nothing_repos.push(repo.name)
        end
      }
      Output.puts_success_message("检查完成！\n")

      if remind_repos.length > 0 && !Output.continue_with_interact_repos?(remind_repos, "以上仓库暂存区无可提交内容，仅存在工作区改动或未跟踪文件，若需要提交这些改动请先add到暂存区。是否跳过并继续？")
        Output.puts_cancel_message
        return
      end

      if do_repos.length != 0
        if argv.git_opts.include?('-m ') || !Output.continue_with_user_remind?("未添加\"-m\"参数，请使用如[ mgit commit -m \"my log\" ]的形式提交。是否取消执行并重新输入（若确实有意执行该指令请忽略本提示）？")

          # commit前调用hook
          HooksManager.execute_mgit_pre_exec_hook(argv.cmd, argv.pure_opts, do_repos.map { |e| e.config })

          msg = "，另有#{do_nothing_repos.length}个仓库暂存区无待提交内容，无须执行" if do_nothing_repos.length > 0
          Output.puts_remind_block(do_repos.map { |repo| repo.name }, "开始commit以上仓库#{msg}...")
          _, error_repos = Workspace.execute_git_cmd_with_repos(argv.cmd, argv.git_opts, do_repos)
          Output.puts_succeed_cmd(argv.absolute_cmd) if error_repos.length == 0
        else
          Output.puts_cancel_message
          return
        end
      else
        Output.puts_remind_message("所有仓库均无改动，无须执行！")
      end
    end

    def enable_repo_selection
      true
    end

    def self.description
      "将修改记录到版本库。"
    end

    def self.usage
      "mgit commit [<git-commit-option>] [(--mrepo|--el-mrepo) <repo>...] [--help]"
    end

  end

end
