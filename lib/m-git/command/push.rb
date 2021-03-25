#coding=utf-8

module MGit

  # @!scope 类似 git push
  # 可自动生成 git gerrit 评审分支
  # mgit push --gerrit
  #
  class Push < BaseCommand

    # 默认是否开启gerrit相关功能
    #
    MGIT_PUSH_GERRIT_ENABLED = false

    # 默认是否开启topic相关功能，开启后强制开启gerrit
    MGIT_PUSH_TOPIC_ENABLED = false

    OPT_LIST = {
      :gerrit     =>  '--gerrit',
      :topic_id   =>  '--topic'
    }.freeze

    def options
      [
          ARGV::Opt.new(OPT_LIST[:gerrit],
                        info:"开启gerrit功能，如果没有对应远程分支则推送新分支，否则推送到审查分支（refs/for/**），默认未开启",
                        type: :boolean),
          ARGV::Opt.new(OPT_LIST[:topic_id],
                        info:"指定一组变更的分类topic，若未指定则自动生成，默认未开启，开启后强制开启Gerrit功能。mgit push --topic 12345 = git push origin HEAD:refs/for/<branch>%topic=12345",
                        type: :string),
      ].concat(super)
    end

    attr_reader :topic_id
    attr_reader :gerrit_enabled
    def __setup_option_value(argv)
      group_id_opt = argv.opt(OPT_LIST[:topic_id])
      if group_id_opt
        @topic_id = group_id_opt.value
      elsif MGIT_PUSH_TOPIC_ENABLED
        @topic_id = SecureRandom.uuid
      end

      @gerrit_enabled = !@topic_id.nil? || argv.opt_list.did_set_opt?(OPT_LIST[:gerrit]) || MGIT_PUSH_GERRIT_ENABLED
    end

    def execute(argv)
      __setup_option_value(argv)
      if argv.git_opts&.length > 0
        raws_string = ''
        argv.raw_opts.each do |raws|
          raws_string += ' '
          raws_string += raws.join(' ')
        end
        Foundation.help!("禁止使用参数 #{argv.git_opts}\n" + Output.remind_message("建议直接使用mgit #{argv.cmd}#{raws_string}"))
      end
      Workspace.check_branch_consistency

      Output.puts_start_cmd

      # 获取远程仓库当前分支信息
      Workspace.pre_fetch

      do_repos = []
      diverged_repos = []
      do_nothing_repos = []
      detached_repos = []
      no_remote_repos = []
      no_tracking_repos = []
      remote_inconsist_repos = []
      dirty_repos = []

      Output.puts_processing_message("检查各仓库状态...")
      Workspace.serial_enumerate_with_progress(all_repos) { |repo|
        Timer.start(repo.name)

        url_consist = repo.url_consist?
        branch_status = repo.status_checker.branch_status
        remote_inconsist_repos.push(repo) if !url_consist

        if branch_status == Repo::Status::GIT_BRANCH_STATUS[:diverged]
          diverged_repos.push(repo)
        # 仅超前且url一致的仓库直接加入到操作集
        elsif branch_status == Repo::Status::GIT_BRANCH_STATUS[:ahead] && url_consist
          do_repos.push(repo)
        elsif branch_status == Repo::Status::GIT_BRANCH_STATUS[:no_remote]
          no_remote_repos.push(repo)
        elsif branch_status == Repo::Status::GIT_BRANCH_STATUS[:no_tracking]
          no_tracking_repos.push(repo)
        elsif branch_status == Repo::Status::GIT_BRANCH_STATUS[:detached]
          detached_repos.push(repo)
        else
          do_nothing_repos.push(repo.name)
        end

        if repo.status_checker.status == Repo::Status::GIT_REPO_STATUS[:dirty]
          dirty_repos.push(repo)
        end

        Timer.stop(repo.name)
      }
      Output.puts_success_message("检查完成！\n")

      # 将没有远程分支的仓库纳入到本次操作的仓库中
      do_repos += no_remote_repos
      no_remote_repos = []

      if diverged_repos.length > 0 ||
        detached_repos.length > 0 ||
        no_remote_repos.length > 0 ||
        no_tracking_repos.length > 0 ||
        remote_inconsist_repos.length > 0 ||
        dirty_repos.length > 0
        remind_repos = []
        remind_repos.push(['远程分支不存在', no_remote_repos.map { |e| e.name }]) if no_remote_repos.length > 0
        remind_repos.push(['未追踪远程分支(建议:mgit branch -u origin/<branch>)', no_tracking_repos.map { |e| e.name }]) if no_tracking_repos.length > 0
        remind_repos.push(['HEAD游离,当前不在任何分支上', detached_repos.map { |e| e.name }]) if detached_repos.length > 0
        remind_repos.push(['当前分支与远程分支分叉,需先pull本地合并', diverged_repos.map { |e| e.name }]) if diverged_repos.length > 0
        remind_repos.push(['实际url与配置不一致', remote_inconsist_repos.map { |e| e.name }]) if remote_inconsist_repos.length > 0
        remind_repos.push(['有本地改动', dirty_repos.map { |e| e.name }]) if dirty_repos.length > 0
        Output.interact_with_multi_selection_combined_repos(remind_repos, "以上仓库状态异常", ['a: 跳过并继续', 'b: 强制执行', 'c: 终止']) { |input|
          if input == 'b'
            do_repos += diverged_repos
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
      if do_repos.length == 0
        Output.puts_remind_message("仓库均无新提交，无须执行！")
        return
      end
      HooksManager.execute_mgit_pre_push_hook(argv.cmd, argv.pure_opts, do_repos.map { |e| e.config })

      # 跳过无法处理的异常状态仓库
      skip_repos = do_repos.select { |repo|
        branch_status = repo.status_checker.branch_status
        branch_status == Repo::Status::GIT_BRANCH_STATUS[:detached] ||
            branch_status == Repo::Status::GIT_BRANCH_STATUS[:no_tracking]
      }
      Output.puts_remind_block(skip_repos.map { |e| e.name }, "以上仓库无法强制执行，已跳过。") if skip_repos.length > 0
      do_repos -= skip_repos
      if do_repos.length == 0
        Output.puts_success_message("仓库均无新提交，无须执行！")
        return
      end

      # 找到本次操作仓库中推新分支的仓库
      no_remote_repo_names = do_repos.select { |repo|
        branch_status = repo.status_checker.branch_status
        branch_status == Repo::Status::GIT_BRANCH_STATUS[:no_remote]
      }.map { |repo| repo.name }

      count_msg = "，另有#{do_nothing_repos.length}个仓库无须执行" if do_nothing_repos.length > 0
      Output.puts_remind_block(do_repos.map { |repo| repo.name }, "开始push以上仓库#{count_msg}...")

      # ------ 执行push ------
      total_task = do_repos.length
      Output.update_progress(total_task, 0)

      config_repo_arr = do_repos.select { |repo| repo.config.is_config_repo }
      do_repos_without_config_repo = do_repos - config_repo_arr

      sub_error_repos, sub_cr_repos = __execute_push(argv, do_repos_without_config_repo) { |progress|
        Output.update_progress(total_task, progress)
      }

      # 保证最后操作主仓库，便于流水线进行模块注册
      sub_task_count = do_repos_without_config_repo.length
      config_error_repos, config_cr_repos = __execute_push(argv, config_repo_arr) { |progress|
        Output.update_progress(total_task, progress + sub_task_count)
      }
      puts "\n"
      # ----------------------
      # 显示错误仓库信息
      error_repos = sub_error_repos.merge(config_error_repos)
      Workspace.show_error(error_repos) if error_repos.length > 0

      # 显示成功推了新分支的仓库
      success_push_branch_repo_names = no_remote_repo_names - error_repos.keys
      if success_push_branch_repo_names.length > 0
        Output.puts_remind_block(success_push_branch_repo_names, "为以上仓库推送了新分支。")
        puts "\n"
      end

      # 显示成功仓库的评审链接
      if gerrit_enabled
        success_output = ''
        all_cr_repos = sub_cr_repos.keys + config_cr_repos.keys
        all_cr_repos.uniq!
        all_cr_repos.each do |repo_name|
          cr_url = sub_cr_repos[repo_name] || config_cr_repos[repo_name]
          success_output += Output.generate_title_block(repo_name, has_separator: false) { cr_url } + "\n\n"
        end

        if success_output.length > 0
          Output.puts_remind_message("以下本地提交代码评审链接，请联系仓库负责人评审后合入：")
          puts success_output
        end

        # 显示topic id
        if topic_id
          success_push_code_repo_names = do_repos.map { |e| e.name } - error_repos.keys - success_push_branch_repo_names
          if success_push_code_repo_names.length > 0
            Output.puts_remind_message("本次push的topic id：#{topic_id}\n") if !topic_id.nil? && topic_id.length > 0
          end
        end
      end

      # 显示成功信息
      if error_repos.empty?
        Output.puts_succeed_cmd(argv.absolute_cmd)
        Timer.show_time_consuming_repos
      elsif topic_id
        # 显示失败后的操作提示，若全部成功则不显示
        group_repo_names = error_repos.keys
        group_repo_name_str = group_repo_names.join(' ')
        is_all = Workspace.is_all_exec_sub_repos_by_name?(group_repo_names)
        mrepo_str = is_all ? '' : " --mrepo #{group_repo_name_str}"
        Output.puts_processing_block(group_repo_names, "以上仓库组推送失败，请处理后用以下指令再次推送：\n\n    mgit push --topic #{topic_id}#{mrepo_str}\n")
      end

    end

    private

    def __execute_push(argv, do_repos)
      mutex = Mutex.new
      error_repos = {}
      cr_repos = {}
      task_count = 0

      Workspace.concurrent_enumerate(do_repos) { |repo|
        cmd, opt = __parse_cmd_and_opt(repo)
        git_cmd = repo.git_cmd(cmd, opt)

        Utils.execute_shell_cmd(git_cmd) { |stdout, stderr, status|
          mutex.lock
          error_msg, cr_url = __process_push_result(repo, stdout, stderr, status)
          error_repos[repo.name] = error_msg if error_msg
          cr_repos[repo.name] = cr_url if cr_url

          task_count += 1
          yield(task_count) if block_given?
          mutex.unlock
        }
      }

      [error_repos, cr_repos]
    end

    #
    # @return [String, String] error_message， code_review_url
    #
    #
    def __process_push_result(repo, stdout, stderr, status)
      # 标记状态更新
      repo.status_checker.refresh

      # 本地成功但远程失败此时status.success? == true，解析以检测这个情况
      repo_msg_parser = GitMessageParser.new(repo.config.url)
      check_msg = repo_msg_parser.parse_push_msg(stderr)

      # 本地和远程同时成功
      if status.success? && check_msg.nil?
        cr_url = repo_msg_parser.parse_code_review_url(stdout) || repo_msg_parser.parse_code_review_url(stderr) if gerrit_enabled
      elsif status.success? && !check_msg.nil?
        # 本地失败
        # check_msg = error_msg
      else
        check_msg = stderr
        check_msg += stdout if stdout.length > 0
      end
      [check_msg, cr_url]
    end

    def __parse_cmd_and_opt(repo)
      cmd = 'push'
      if repo.status_checker.branch_status == Repo::Status::GIT_BRANCH_STATUS[:no_remote]
        opt = "-u origin #{repo.status_checker.current_branch}"
      else
        opt = "origin HEAD:#{repo.status_checker.current_branch}"
        if gerrit_enabled
          opt = "origin HEAD:refs/for/#{repo.status_checker.current_branch}"
          opt += "%topic=" + topic_id if topic_id
        end
      end
      [cmd, opt]
    end

    def enable_repo_selection
      return true
    end

    def self.description
      return "更新远程分支和对应的数据对象。"
    end

    def self.usage
      return "mgit push [<git-push-option>|--gerrit] [(--mrepo|--el-mrepo) <repo>...] [--topic] [--help]"
    end

  end

end
