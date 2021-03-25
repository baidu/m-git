#coding=utf-8

module MGit

  # @!scope [command] checkout
  # follow git checkout
  # eg: mgit checkout master
  #
  class Checkout < BaseCommand

    def execute(argv)
      Output.puts_start_cmd

      # 优先checkout配置仓库
      config_repo = generate_config_repo
      checkout_config_repo(argv.cmd, argv.git_opts, config_repo)

      do_repos = []
      dirty_repos = []

      Output.puts_processing_message("检查各仓库状态...")
      Workspace.serial_enumerate_with_progress(all_repos) { |repo|
        if !config_repo.nil? && repo.name == config_repo.name
          next
        elsif repo.status_checker.status != Repo::Status::GIT_REPO_STATUS[:dirty]
          do_repos.push(repo)
        else
          dirty_repos.push(repo)
        end
      }
      Output.puts_success_message("检查完成！\n")

      if dirty_repos.length > 0
        remind_repos = []
        remind_repos.push(['有本地改动', dirty_repos.map { |e| e.name }]) if dirty_repos.length > 0
        Output.interact_with_multi_selection_combined_repos(remind_repos, "以上仓库状态异常", ['a: 跳过并继续', 'b: 强制执行', 'c: 终止']) { |input|
          if input == 'b'
            do_repos += dirty_repos
            do_repos.uniq! { |repo| repo.name }
          elsif input == 'c' || input != 'a'
            Output.puts_cancel_message
            return
          end
        }
      end

      if do_repos.length == 0
        if config_repo.nil?
          Output.puts_nothing_to_do_cmd
        else
          Output.puts_succeed_cmd(argv.absolute_cmd)
        end
      else
        Output.puts_processing_message("开始checkout子仓库...")
        _, error_repos = Workspace.execute_git_cmd_with_repos(argv.cmd, argv.git_opts, do_repos)
        Output.puts_succeed_cmd(argv.absolute_cmd) if error_repos.length == 0
      end
    end

    def checkout_config_repo(cmd, opts, repo)
      return if repo.nil?
      if repo.status_checker.status == Repo::Status::GIT_REPO_STATUS[:dirty]
        remind_config_repo_fail("主仓库\"#{repo.name}\"有改动，无法执行！")
      else
        Output.puts_processing_message("开始checkout主仓库...")
        success, output = repo.execute_git_cmd(cmd, opts)
        if !success
          remind_config_repo_fail("主仓库\"#{repo.name}\"执行\"#{cmd}\"失败：\n#{output}")
        else
          Output.puts_success_message("主仓库checkout成功！\n")
        end

        # 刷新配置表
        Workspace.update_config { |missing_repos|
          if missing_repos.length > 0
            all_repos.concat(missing_repos)
            # missing_repos包含新下载的和当前分支已有的新仓库，其中已有仓库包含在@all_repos内，需要去重
            all_repos.uniq! { |repo| repo.name }
          end
        }

      end
    end

    def remind_config_repo_fail(msg)
      Output.puts_fail_message(msg)
      return if Output.continue_with_user_remind?("是否继续操作其余仓库？")
      Output.puts_cancel_message
      exit
    end

    def enable_repo_selection
      true
    end

    def self.description
      "切换分支或恢复工作区改动。"
    end

    def self.usage
      "mgit checkout [<git-checkout-option>] [(--mrepo|--el-mrepo) <repo>...] [--help]"
    end

  end

end
