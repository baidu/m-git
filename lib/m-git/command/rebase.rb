#coding=utf-8

module MGit

  # @!scope 类似 git rebase
  #
  class Rebase < BaseCommand

    PROGRESS_STAGE = {
      :new_start          => 0,
      :did_pull_config    => 1,
      :did_refresh_config => 2,
      :did_pull_sub       => 3
    }.freeze
    PROGRESS_STAGE_KEY = 'progress_stage'

    PROGRESS_AUTO = 'auto_exec'

    OPT_LIST = {
      :pull      => '--pull'
    }.freeze

    def options
      [
          ARGV::Opt.new(OPT_LIST[:pull], info:'可选参数，指定后在合并仓库前会拉取远程分支更新代码，如："mgit rabase --pull"。', type: :boolean)
      ].concat(super)
    end

    def execute(argv)
      return if do_abort(argv)

      check_master_rebase(argv)
      Workspace.check_branch_consistency

      Output.puts_start_cmd

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

        cmd = context.cmd
        opts = context.opts
        config_error = continue_execute(cmd, opts, config_repo, context.other[PROGRESS_STAGE_KEY], context.other[PROGRESS_AUTO])
        if config_error
          Output.puts_fail_block([config_repo.name], "主仓库操作失败：#{config_error}")
          return
        end
      else
        # 处于中间态则提示
        if OperationProgressManager.is_in_progress?(Workspace.root, __progress_type)
          if Output.continue_with_user_remind?("当前处于操作中间态，建议取消操作并执行\"mgit merge --continue\"继续操作未完成仓库。\n    继续执行将清除中间态并重新操作所有仓库，是否取消？")
            Output.puts_cancel_message
            return
          end
        end

        cmd = argv.cmd
        opts = argv.git_opts

        # 优先操作配置仓库
        config_error = rebase_config_repo(cmd, opts, config_repo, argv.opt_list.did_set_opt?(OPT_LIST[:pull]))
        if config_error
          Output.puts_fail_block([config_repo.name], "主仓库操作失败：#{config_error}")
          return
        end
      end

      do_repos = []
      dirty_repos = []
      detached_repos = []
      no_tracking_repos = []

      Output.puts_processing_message("检查各仓库状态...")
      Workspace.serial_enumerate_with_progress(all_repos) { |repo|
        next if !config_repo.nil? && repo.name == config_repo.name

        status = repo.status_checker.status
        branch_status = repo.status_checker.branch_status

        if status == Repo::Status::GIT_REPO_STATUS[:clean] &&
          branch_status != Repo::Status::GIT_BRANCH_STATUS[:detached] &&
          branch_status != Repo::Status::GIT_BRANCH_STATUS[:no_tracking]
          do_repos.push(repo)
        else
          if status == Repo::Status::GIT_REPO_STATUS[:dirty]
            dirty_repos.push(repo)
          end
          if branch_status == Repo::Status::GIT_BRANCH_STATUS[:detached]
            detached_repos.push(repo)
          elsif branch_status == Repo::Status::GIT_BRANCH_STATUS[:no_tracking]
            no_tracking_repos.push(repo)
          end
        end
      }
      Output.puts_success_message("检查完成！\n")

      if dirty_repos.length > 0 || no_tracking_repos.length > 0 || detached_repos.length > 0
        remind_repos = []
        remind_repos.push(['有本地改动', dirty_repos.map { |e| e.name }])
        remind_repos.push(['未追踪远程分支(建议:mgit branch -u origin/<branch>)', no_tracking_repos.map { |e| e.name }]) if no_tracking_repos.length > 0
        remind_repos.push(['HEAD游离,当前不在任何分支上', detached_repos.map { |e| e.name }]) if detached_repos.length > 0
        Output.interact_with_multi_selection_combined_repos(remind_repos, "以上仓库状态异常", ['a: 跳过并继续', 'b: 强制执行', 'c: 终止']) { |input|
          if input == 'b'
            do_repos += dirty_repos
            do_repos += detached_repos
            do_repos += no_tracking_repos
            do_repos.uniq! { |repo| repo.name }
          elsif input == 'c' || input != 'a'
            Output.puts_cancel_message
            return
          end
        }
      end

      if do_repos.length == 0
        Output.puts_remind_message("没有仓库需要执行rebase指令！") if config_repo.nil?
      else
        Output.puts_processing_message("开始rebase子仓库...")
        _, error_repos = Workspace.execute_git_cmd_with_repos(cmd, opts, do_repos)
      end

      Output.puts_succeed_cmd("#{cmd} #{opts}") if config_error.nil? || error_repos.empty?

      # 清除中间态
      OperationProgressManager.remove_progress(Workspace.root, __progress_type)
    end

    # 合并主仓库
    #
    # @param cmd [String] 合并指令
    #
    # @param opts [String] 合并参数
    #
    # @param repo [Repo] 配置仓库对象
    #
    # @param exec_repos [Array<Repo>] 本次操作的所有仓库（含配置仓库）
    #
    def rebase_config_repo(cmd, opts, repo, auto_update)
      return if repo.nil?
      branch_status = repo.status_checker.branch_status
      if branch_status == Repo::Status::GIT_BRANCH_STATUS[:detached]
        remind_config_repo_fail("主仓库\"#{repo.name}\"HEAD游离，当前不在任何分支上，无法执行!")
      elsif branch_status == Repo::Status::GIT_BRANCH_STATUS[:no_tracking]
        remind_config_repo_fail("主仓库\"#{repo.name}\"未跟踪对应远程分支，无法执行！(需要执行'mgit branch -u origin/<branch>')")
      elsif repo.status_checker.status == Repo::Status::GIT_REPO_STATUS[:dirty]
        remind_config_repo_fail("主仓库\"#{repo.name}\"有改动，无法执行\"#{cmd}\"!")
      else
        return continue_execute(cmd, opts, repo, PROGRESS_STAGE[:new_start], auto_update)
      end
    end

    def continue_execute(cmd, opts, repo, check_point, auto_update)

      # 现场信息
      exec_subrepos = all_repos(except_config:true)
      is_all = Workspace.is_all_exec_sub_repos?(exec_subrepos)
      context = OperationProgressContext.new(__progress_type)
      context.cmd = cmd
      context.opts = opts
      context.repos = is_all ? nil : exec_subrepos.map { |e| e.name } # nil表示操作所有子仓库
      context.branch = repo.status_checker.current_branch(use_cache:true)

      # 更新主仓库
      update_config_repo(repo, context, auto_update) if check_point < PROGRESS_STAGE[:did_pull_config]

      if check_point < PROGRESS_STAGE[:did_refresh_config]
        # 操作主仓库
        config_error = exec_config_repo(repo, cmd, opts)
        return config_error if config_error
        # 更新配置表
        refresh_config(repo, context, auto_update)
      end

      if check_point < PROGRESS_STAGE[:did_pull_sub]
        # 如果本次操作所有子仓库，则再次获取所有子仓库（因为配置表可能已经更新，子仓库列表也有更新，此处获取的仓库包含：已有的子仓库 + 合并后新下载仓库 + 从缓存弹出的仓库）
        exec_subrepos = all_repos(except_config:true) if context.repos.nil?
        # 更新子仓库
        update_subrepos(exec_subrepos, context, auto_update)
      end

      config_error
    end

    def update_config_repo(repo, context, auto)
      if auto || Output.continue_with_user_remind?("即将合并主仓库，是否先拉取远程代码更新？")
        Output.puts_processing_message("正在更新主仓库...")
        success, output = repo.execute_git_cmd('pull', '')
        if !success
          context.other = {
            PROGRESS_STAGE_KEY => PROGRESS_STAGE[:did_pull_config],
            PROGRESS_AUTO => auto
          }
          OperationProgressManager.trap_into_progress(Workspace.root, context)
          show_progress_error("主仓库更新失败", "#{output}")
        else
          Output.puts_success_message("更新成功！\n")
        end
      end
    end

    def exec_config_repo(repo, cmd, opts)
      error = nil
      Output.puts_processing_message("开始操作主仓库...")
      success, output = repo.execute_git_cmd(cmd, opts)
      if success
        Output.puts_success_message("操作成功！\n")
      else
        Output.puts_fail_message("操作失败！\n")
        error = output
      end
      error
    end

    # 刷新配置表
    def refresh_config(repo, context, auto)
      begin
        Workspace.update_config(strict_mode:false) { |missing_repos|
          if missing_repos.length > 0
            # 这里分支引导仅根据主仓库来进行，如果使用all_repos来作为引导
            # 基准，可能不准确(因为all_repos可能包含merge分支已有的本地
            # 仓库，而这些仓库所在分支可能五花八门，数量也可能多于处于正确
            # 分支的仓库)。
            success_missing_repos = Workspace.guide_to_checkout_branch(missing_repos, [repo], append_message:"拒绝该操作本次执行将忽略以上仓库")
            all_repos.concat(success_missing_repos)
            # success_missing_repos包含新下载的和当前分支已有的新仓库，其中已有仓库包含在@all_repos内，需要去重
            all_repos.uniq! { |repo| repo.name }
          end
        }
        refresh_context(context)
      rescue Error => e
        if e.type == MGIT_ERROR_TYPE[:config_generate_error]
          context.other = {
            PROGRESS_STAGE_KEY => PROGRESS_STAGE[:did_refresh_config],
            PROGRESS_AUTO => auto
          }

          OperationProgressManager.trap_into_progress(Workspace.root, context)
          show_progress_error("配置表生成失败", "#{e.msg}")
        end
      end
    end

    def update_subrepos(subrepos, context, auto)
      if auto || Output.continue_with_user_remind?("即将合并子仓库，是否先拉取远程代码更新？")
        Output.puts_processing_message("正在更新子仓库...")
        _, error_repos = Workspace.execute_git_cmd_with_repos('pull', '', subrepos)
        if error_repos.length > 0
          context.other = {
            PROGRESS_STAGE_KEY => PROGRESS_STAGE[:did_pull_sub],
            PROGRESS_AUTO => auto
          }
          OperationProgressManager.trap_into_progress(Workspace.root, context)
          show_progress_error("子仓库更新失败", "见上述输出")
        else
          Output.puts_success_message("更新成功！\n")
        end
      end
    end

    def refresh_context(context)
      exec_subrepos = all_repos(except_config:true)
      is_all = Workspace.is_all_exec_sub_repos?(exec_subrepos)
      context.repos = is_all ? nil : exec_subrepos.map { |e| e.name } # nil表示操作所有子仓库
    end

    def remind_config_repo_fail(msg)
      Output.puts_fail_message(msg)
      return if Output.continue_with_user_remind?("是否继续操作其余仓库？")
      Output.puts_cancel_message
      exit
    end

    def check_master_rebase(argv)
      opt_arr = argv.git_opts(raw:false)
      opt_arr.each { |opts|
        Foundation.help!("当前版本不支持\"-i\"或\"--interactive\"参数，请重试。") if ['-i','--interactive'].include?(opts.first)
      }
    end

    def do_abort(argv)
      return false unless argv.git_opts.include?('--abort')
      Output.puts_start_cmd
      OperationProgressManager.remove_progress(Workspace.root, __progress_type)
      do_repos = all_repos.select { |repo| repo.status_checker.is_in_rebase_progress? }

      if do_repos.length > 0
        append_message = "，另有#{all_repos.length - do_repos.length}个仓库无须操作" if do_repos.length < all_repos.length
        Output.puts_processing_block(do_repos.map { |e| e.name }, "开始操作以上仓库#{append_message}...")
        _, error_repos = Workspace.execute_git_cmd_with_repos(argv.cmd, argv.git_opts, do_repos)
        Output.puts_succeed_cmd(argv.absolute_cmd) if error_repos.length == 0
      else
        Output.puts_success_message("没有仓库需要操作！")
      end

      true
    end

    def show_progress_error(summary, detail)
      error = "#{summary} 已进入操作中间态。

原因：
  #{detail}

可选：
  - 使用\"mgit rebase --continue\"继续变基。
  - 使用\"mgit rebase --abort\"取消变基。"
      Foundation.help!(error, title:'暂停')
    end

    def enable_repo_selection
      true
    end

    def enable_continue_operation
      true
    end

    def self.description
      "重新将提交应用到其他基点，该命令不执行lock的仓库。"
    end

    def self.usage
      "mgit rebase [<git-rebase-option>] [(--mrepo|--el-mrepo) <repo>...] [--help]\nmgit rebase --continue\nmgit rebase --abort"
    end

    private

    def __progress_type
      OperationProgressManager::PROGRESS_TYPE[:rebase]
    end

  end

end
