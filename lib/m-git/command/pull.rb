#coding=utf-8

module MGit

  # @!scope 类似 git pull
  #
  class Pull < BaseCommand

    OPT_LIST = {
      :no_check    => '--no-check',
    }.freeze

    def options
      [
          ARGV::Opt.new(OPT_LIST[:no_check], info:'指定该参数意味着执行前跳过仓库的状态检查，直接对指定或所有仓库执行pull操作，有一定风险，请慎重执行。', type: :boolean),
      ].concat(super)
    end

    def __progress_type
      OperationProgressManager::PROGRESS_TYPE[:pull]
    end

    def execute(argv)
      if argv.opt(OPT_LIST[:no_check])
        simple_pull(argv)
        return
      end

      verbose_pull(argv)
    end

    def verbose_pull(argv)
      return if do_abort(argv)

      Output.puts_start_cmd

      # 获取远程仓库当前分支信息
      Workspace.pre_fetch

      config_repo = generate_config_repo

      if mgit_try_to_continue?
        # 不处于中间态禁止执行
        Foundation.help!("当前并不处于操作中间态，无法进行continue操作！") if !OperationProgressManager.is_in_progress?(Workspace.root, __progress_type)

        # 读取指令缓存失败禁止执行
        context, _ = OperationProgressManager.load_context(Workspace.root, __progress_type)
        Foundation.help!("缓存指令读取失败，continue无法继续进行，请重新执行完整指令。") if context.nil? || !context.validate?

        # 分支不匹配禁止执行
        Foundation.help!("当前主仓库所在分支跟上次操作时所在分支(#{context.branch})不一致，请切换后重试。") if config_repo.status_checker.current_branch(use_cache:true) != context.branch

        if !context.repos.nil?
          Output.puts_processing_message("加载上次即将操作的子仓库...")
          Workspace.update_all_repos(context.repos)
        end

        Output.puts_success_message("已跳过主仓库。")

      else

        # 处于中间态则提示
        if OperationProgressManager.is_in_progress?(Workspace.root, __progress_type)
          if Output.continue_with_user_remind?("当前处于操作中间态，建议取消操作并执行\"mgit pull --continue\"继续操作子仓库。\n    继续执行将清除中间态并重新操作所有仓库，是否取消？")
            Output.puts_cancel_message
            return
          end
        end

        # 优先pull配置仓库
        config_error = pull_config_repo(argv.cmd, argv.git_opts, config_repo)
        if config_error
          Output.puts_fail_block([config_repo.name], "主仓库操作失败：#{config_error}")
          return
        end
      end

      do_repos = []
      diverged_repos = []
      no_remote_repos = []
      no_tracking_repos = []
      dirty_repos = []
      detached_repos = []
      remote_inconsist_repos = []
      do_nothing_repos = []

      Output.puts_processing_message("检查各仓库状态...")
      Workspace.serial_enumerate_with_progress(all_repos) { |repo|
        next if !config_repo.nil? && repo.name == config_repo.name

        Timer.start(repo.name)
        status = repo.status_checker.status
        branch_status = repo.status_checker.branch_status

        if branch_status == Repo::Status::GIT_BRANCH_STATUS[:up_to_date] || branch_status == Repo::Status::GIT_BRANCH_STATUS[:ahead]
          # 领先和最新的仓库均不操作
          do_nothing_repos.push(repo)
        else

          url_consist = repo.url_consist?
          is_dirty = status == Repo::Status::GIT_REPO_STATUS[:dirty]
          dirty_repos.push(repo) if is_dirty
          remote_inconsist_repos.push(repo) if !url_consist

          # 仅有分叉或落后，且工作区干净的仓库直接加入到操作集
          if branch_status == Repo::Status::GIT_BRANCH_STATUS[:diverged] && !is_dirty && url_consist
            do_repos.push(repo)
            diverged_repos.push(repo.name)
          elsif branch_status == Repo::Status::GIT_BRANCH_STATUS[:behind] && !is_dirty && url_consist
            do_repos.push(repo)
          elsif branch_status == Repo::Status::GIT_BRANCH_STATUS[:no_remote]
            no_remote_repos.push(repo)
          elsif branch_status == Repo::Status::GIT_BRANCH_STATUS[:no_tracking]
            no_tracking_repos.push(repo)
          elsif branch_status == Repo::Status::GIT_BRANCH_STATUS[:detached]
            detached_repos.push(repo)
          end

        end
        Timer.stop(repo.name)
      }
      Output.puts_success_message("检查完成！\n")

      if Workspace.filter_config.auto_exec
        do_repos += dirty_repos
        do_repos.uniq! { |repo| repo.name }
      elsif no_remote_repos.length > 0 ||
        dirty_repos.length > 0 ||
        detached_repos.length > 0 ||
        no_tracking_repos.length > 0 ||
        remote_inconsist_repos.length > 0
        remind_repos = []
        remind_repos.push(['远程分支不存在', no_remote_repos.map { |e| e.name }]) if no_remote_repos.length > 0
        remind_repos.push(['未追踪远程分支(建议:mgit branch -u origin/<branch>)', no_tracking_repos.map { |e| e.name }]) if no_tracking_repos.length > 0
        remind_repos.push(['有本地改动', dirty_repos.map { |e| e.name }]) if dirty_repos.length > 0
        remind_repos.push(['HEAD游离,当前不在任何分支上', detached_repos.map { |e| e.name }]) if detached_repos.length > 0
        remind_repos.push(['实际url与配置不一致', remote_inconsist_repos.map { |e| e.name }]) if remote_inconsist_repos.length > 0
        Output.interact_with_multi_selection_combined_repos(remind_repos, "以上仓库状态异常", ['a: 跳过并继续', 'b: 强制执行', 'c: 终止']) { |input|
          if input == 'b'
            do_repos += dirty_repos
            do_repos += detached_repos
            do_repos += no_remote_repos
            do_repos += no_tracking_repos
            do_repos += remote_inconsist_repos
            do_repos.uniq! { |repo| repo.name }
          elsif input == 'c' || input != 'a'
            Output.puts_cancel_message
            return
          end
        }
      end

      if do_repos.length != 0
        error_repos = []
        # 如果不带任何参数，则将pull分解为fetch+merge执行, fetch已经执行，此处执行merge。带参数则透传。
        if argv.git_opts.length == 0
          # 排除HEAD游离，无远程分支，未追踪远程分支的仓库，这三种仓库是无法强制执行git pull的（但是可以执行如：git pull origin master，因此透传不做此校验）
          skip_repos = do_repos.select { |repo|
            branch_status = repo.status_checker.branch_status
            branch_status == Repo::Status::GIT_BRANCH_STATUS[:no_remote] ||
            branch_status == Repo::Status::GIT_BRANCH_STATUS[:no_tracking] ||
            branch_status == Repo::Status::GIT_BRANCH_STATUS[:detached]
          }
          if skip_repos.length > 0
            Output.puts_remind_block(skip_repos.map { |e| e.name }, "以上仓库无法强制执行，已跳过。")
            do_repos -= skip_repos
            if do_repos.length == 0
              Output.puts_success_message("仓库均为最新，无须执行！")
              return
            end
          end

          count_msg = "，另有#{do_nothing_repos.length}个仓库无须执行" if do_nothing_repos.length > 0
          Output.puts_remind_block(do_repos.map { |repo| repo.name }, "开始为以上仓库合并远程分支#{count_msg}...")
          _, error_repos = Workspace.execute_git_cmd_with_repos('', '', do_repos) { |repo|
            msg = nil
            branch = repo.status_checker.current_branch(strict_mode:false, use_cache:true)
            tracking_branch = repo.status_checker.tracking_branch(branch, use_cache:true)
            # 如果产生分叉，为生成的新节点提供log
            msg = "-m \"【Merge】【0.0.0】【#{branch}】合并远程分支'#{tracking_branch}'。\"" if diverged_repos.include?(repo.name)
            ["merge", "#{tracking_branch} #{msg}"]
          }
        else
          count_msg = "，另有#{do_nothing_repos.length}个仓库无须执行" if do_nothing_repos.length > 0
          Output.puts_remind_block(do_repos.map { |repo| repo.name }, "开始pull以上仓库#{count_msg}...")
          _, error_repos = Workspace.execute_git_cmd_with_repos(argv.cmd, argv.git_opts, do_repos)
        end

        if config_error.nil? && error_repos.length == 0
          Output.puts_succeed_cmd(argv.absolute_cmd)
          Timer.show_time_consuming_repos
        end

      else
        Output.puts_success_message("仓库均为最新，无须执行！")
      end

      # 清除中间态
      OperationProgressManager.remove_progress(Workspace.root, __progress_type)
    end

    def simple_pull(argv)
      Output.puts_start_cmd

      # 优先pull配置仓库
      config_repo = generate_config_repo
      config_error = pull_config_repo(argv.cmd, argv.git_opts, config_repo)

      Output.puts_processing_message("开始pull子仓库...")
      _, error_repos = Workspace.execute_git_cmd_with_repos(argv.cmd, argv.git_opts, all_repos)

      if config_error.nil? && error_repos.length == 0
        Output.puts_succeed_cmd(argv.absolute_cmd)
      elsif !config_error.nil?
        Output.puts_fail_block([config_repo.name], "主仓库操作失败：#{config_error}")
      end

      # 情况中间态
      OperationProgressManager.remove_progress(Workspace.root, __progress_type)
    end

    def pull_config_repo(cmd, opts, repo)
      if !repo.nil?
        branch_status = repo.status_checker.branch_status
        if branch_status == Repo::Status::GIT_BRANCH_STATUS[:detached]
          remind_config_repo_fail("主仓库\"#{repo.name}\"HEAD游离，当前不在任何分支上，无法执行！")
        elsif branch_status == Repo::Status::GIT_BRANCH_STATUS[:no_tracking]
          remind_config_repo_fail("主仓库\"#{repo.name}\"未跟踪对应远程分支，无法执行！(需要执行'mgit branch -u origin/<branch>')")
        elsif branch_status == Repo::Status::GIT_BRANCH_STATUS[:no_remote]
          remind_config_repo_fail("主仓库\"#{repo.name}\"远程分支不存在，无法执行！")
        # elsif repo.status_checker.status == Repo::Status::GIT_REPO_STATUS[:dirty]
        #   remind_config_repo_fail("主仓库\"#{repo.name}\"有改动，无法执行！")
        else

          Output.puts_processing_message("开始操作主仓库...")

          # 现场信息
          exec_subrepos = all_repos(except_config:true)
          is_all = Workspace.is_all_exec_sub_repos?(exec_subrepos)
          context = OperationProgressContext.new(__progress_type)
          context.cmd = cmd
          context.opts = opts
          context.repos = is_all ? nil : exec_subrepos.map { |e| e.name } # nil表示操作所有子仓库
          context.branch = repo.status_checker.current_branch(use_cache:true)

          # 如果不带任何参数，则将pull分解为fetch+merge执行, fetch已经执行，此处执行merge。带参数则透传。
          if opts.length == 0
            branch = repo.status_checker.current_branch(strict_mode:false, use_cache:true)
            tracking_branch = repo.status_checker.tracking_branch(branch, use_cache:true)
            msg = "-m \"【Merge】【0.0.0】【#{branch}】合并远程分支'#{tracking_branch}'。\"" if branch_status == Repo::Status::GIT_BRANCH_STATUS[:diverged]
            cmd, opts = "merge", "#{tracking_branch} #{msg}"
          end

          success, output = repo.execute_git_cmd(cmd, opts)
          if success
            Output.puts_success_message("主仓库操作成功！\n")
          else
            Output.puts_fail_message("主仓库操作失败！\n")
            config_error = output
          end

          # 刷新配置表
          begin
            Workspace.update_config(strict_mode:false) { |missing_repos|
              if missing_repos.length > 0
                success_missing_repos = Workspace.guide_to_checkout_branch(missing_repos, all_repos, append_message:"拒绝该操作本次执行将忽略以上仓库")
                all_repos.concat(success_missing_repos)
                # success_missing_repos包含新下载的和当前分支已有的新仓库，其中已有仓库包含在@all_repos内，需要去重
                all_repos.uniq! { |repo| repo.name }
              end
            }
            refresh_context(context)
          rescue Error => e
            if e.type == MGIT_ERROR_TYPE[:config_generate_error]
              OperationProgressManager.trap_into_progress(Workspace.root, context)
              show_progress_error("配置表生成失败", "#{e.msg}")
            end
          end

          return config_error
        end
      end
    end

    def remind_config_repo_fail(msg)
      Output.puts_fail_message(msg)
      if Workspace.filter_config.auto_exec || Output.continue_with_user_remind?("是否继续操作其余仓库？")
        return
      else
        Output.puts_cancel_message
        exit
      end
    end

    def do_abort(argv)
      if mgit_try_to_abort?
        Output.puts_start_cmd
        OperationProgressManager.remove_progress(Workspace.root, __progress_type)
        do_repos = all_repos.select { |repo| repo.status_checker.is_in_merge_progress? }

        if do_repos.length > 0
          append_message = "，另有#{all_repos.length - do_repos.length}个仓库无须操作" if do_repos.length < all_repos.length
          Output.puts_processing_block(do_repos.map { |e| e.name }, "开始操作以上仓库#{append_message}...")
          _, error_repos = Workspace.execute_git_cmd_with_repos('merge', '--abort', do_repos)
          Output.puts_succeed_cmd(argv.absolute_cmd) if error_repos.length == 0
        else
          Output.puts_success_message("没有仓库需要操作！")
        end

        return true
      else
        return false
      end
    end

    def refresh_context(context)
      exec_subrepos = all_repos(except_config:true)
      is_all = Workspace.is_all_exec_sub_repos?(exec_subrepos)
      context.repos = is_all ? nil : exec_subrepos.map { |e| e.name } # nil表示操作所有子仓库
    end

    def show_progress_error(summary, detail)
      error = "#{summary} 已进入操作中间态。

原因：
  #{detail}

可选：
  - 使用\"mgit pull --continue\"继续拉取。
  - 使用\"mgit pull --abort\"取消拉取。"
      Foundation.help!(error, title:'暂停')
    end

    def enable_repo_selection
      return true
    end

    def enable_auto_execution
      return true
    end

    def include_lock_by_default
      return true
    end

    def enable_continue_operation
      return true
    end

    def enable_abort_operation
      return true
    end

    def self.description
      return "从仓库或本地分支获取数据并合并。"
    end

    def self.usage
      return "mgit pull [<git-pull-option>] [(--mrepo|--el-mrepo) <repo>...] [--auto-exec] [--no-check] [--include-lock] [--help]\nmgit pull --continue\nmgit pull --abort"
    end

  end

end
