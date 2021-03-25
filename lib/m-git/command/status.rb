#coding=utf-8

module MGit

  # @!scope 类似 git status
  #
  class Status < BaseCommand
    def execute(argv)
      Output.puts_processing_message("正在检查各仓库状态...")

      status_info = {}
      mutex = Mutex.new
      mutex_branch = Mutex.new
      mutex_modification = Mutex.new
      mutex_other = Mutex.new

      branch_notice = []
      modification_notice = []
      other_notice = []
      in_progress_notice = []

      task_count = 0
      repo_combo = all_repos + locked_repos
      Output.update_progress(repo_combo.length, task_count)
      Workspace.concurrent_enumerate(repo_combo) { |repo|
        status_msg = ''
        info = []

        # 非锁定仓库进行常规分支检查
        if !locked_repos.include?(repo) &&
          repo.status_checker.branch_status != Repo::Status::GIT_BRANCH_STATUS[:up_to_date] &&
          repo.status_checker.branch_status != Repo::Status::GIT_BRANCH_STATUS[:no_remote]
            info.push(['分支', [repo.status_checker.branch_message]])

            mutex_branch.lock
            branch_notice.push(repo.name)
            mutex_branch.unlock
        end

        # 检查工作区状态
        if repo.status_checker.status != Repo::Status::GIT_REPO_STATUS[:clean]
          info += repo.status_checker.message
          mutex_modification.lock
          modification_notice.push(repo.name)
          mutex_modification.unlock
        end

        # 检查url是否一致
        if !repo.url_consist?
          info.push(['其他', ['仓库实际url与当前配置不一致']])
          mutex_other.lock
          other_notice.push(repo.name)
          mutex_other.unlock
        end

        # 生成表格
        status_msg = Output.generate_table_combination(info) + "\n\n" if info.length > 0

        # 压缩状态信息
        mutex.lock
        if status_msg.length > 0
          status_info[status_msg] = {'repo_names' => [], 'info' => info} if status_info[status_msg].nil?
          status_info[status_msg]['repo_names'].push(repo.name)
        end
        task_count += 1
        Output.update_progress(repo_combo.length, task_count)
        mutex.unlock
      }

      status_info.each_with_index { |(status_msg, item), index|
        info = item['info']
        repo_names = item['repo_names']
        Output.puts_remind_block(repo_names, "以上仓库状态：")
        MGit::Loger.info(info)
        status_msg += "\n" if index != status_info.length - 1
        puts status_msg
      }

      OperationProgressManager::PROGRESS_TYPE.each { |type, type_str|
        if OperationProgressManager.is_in_progress?(Workspace.root, type_str)
          in_progress_notice.push(type.to_s)
        end
      }

      summary = []
      if branch_notice.length > 0
        summary.push(["分支提醒(#{branch_notice.length})",branch_notice])
      end

      if modification_notice.length > 0
        summary.push(["改动提醒(#{modification_notice.length})",modification_notice])
      end

      if other_notice.length > 0
        summary.push(["其他警告(#{other_notice.length})", other_notice])
      end

      if in_progress_notice.length > 0
        summary.push(["处于中间态的操作",in_progress_notice])
      end

      if summary.length > 0
        puts "\n"
        puts Output.generate_table_combination(summary, title: "状态小结", separator: "|")
        MGit::Loger.info('状态小结')
        MGit::Loger.info(summary)
      end

      Output.puts_success_message("所查询仓库均无改动！") if status_info.keys.length == 0

      Output.puts_succeed_cmd(argv.absolute_cmd)
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
      "输出所有仓库的状态。包括：\"分支\"，\"暂存区\"，\"工作区\"，\"特殊（未跟踪和被忽略）\"，\"冲突\"。"
    end

    def self.usage
      "mgit status [(-m|-e) <repo>...] [-h]"
    end
  end

end
