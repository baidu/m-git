#coding=utf-8

module MGit

  # @!scope 类似 git stash，但是强制标记名称
  #
  class Stash < BaseCommand

    OPT_LIST = {
      :push     => '--push',
      :pop      => '--pop',
      :apply    => '--apply',
      :list     => '--list',
      :clear    => '--clear',
    }.freeze

    def options
      return [
          ARGV::Opt.new(OPT_LIST[:push], info:'添加储藏：mgit stash --push "stash_name"。', type: :string),
          ARGV::Opt.new(OPT_LIST[:pop], info:'恢复储藏：mgit stash --pop "stash_name"。', type: :string),
          ARGV::Opt.new(OPT_LIST[:apply], info:'恢复储藏：mgit stash --apply "stash_name"。', type: :string),
          ARGV::Opt.new(OPT_LIST[:list], info:'显示储藏列表。', type: :boolean),
          ARGV::Opt.new(OPT_LIST[:clear], info:'清空所有储藏。', type: :boolean)
      ].concat(super)
    end

    def validate(argv)
      missing_msg = "缺失必要参数"  if argv.raw_opts.length == 0
      illegal_msg = "输入非法参数：#{argv.git_opts}" if argv.git_opts.length > 0
      conjunction = "，同时" if !missing_msg.nil? && !illegal_msg.nil?
      Foundation.help!("#{missing_msg}#{conjunction}#{illegal_msg}，请通过\"mgit #{argv.cmd} --help\"查看用法。") if !missing_msg.nil? || !illegal_msg.nil?
    end

    # 注意：git stash相关命令不支持指定“working tree”和“git dir”
    # 如：git --git-dir=/path/to/.git --work-tree=/path/to/working-tree stash list，若当前不在working tree目录下，则将无法执行。
    def execute(argv)
      argv.enumerate_valid_opts { |opt|
        if opt.key == OPT_LIST[:push]
          do_stash_push(argv, opt.value)
          break
        elsif opt.key == OPT_LIST[:pop] || opt.key == OPT_LIST[:apply]
          action = opt.key.gsub('--', '')
          do_stash_pop_apply(argv, opt.value, action)
          break
        elsif opt.key == OPT_LIST[:list]
          do_stash_list(argv)
        elsif opt.key == OPT_LIST[:clear]
          do_clear(argv)
        end
      }
    end

    def do_clear(argv)
      if Output.continue_with_user_remind?("该操作会丢失所有的stash，确定要执行吗？")
        Output.puts_start_cmd
        abs_cmd = "git stash clear"
        _, error_repos = Workspace.execute_common_cmd_with_repos(abs_cmd, all_repos)
        Output.puts_succeed_cmd(argv.absolute_cmd) if error_repos.length == 0
      else
        Output.puts_cancel_message
      end
    end

    def do_stash_list(argv)
      Output.puts_start_cmd

      error_repos = {}
      all_repos.each { |repo|
        cmd = "git -C \"#{repo.path}\" stash list"
        success, output = repo.execute(cmd)
        if success
          puts Output.generate_title_block(repo.name) {
            output
          } + "\n" if output.length > 0
        else
          error_repos[repo.name] = output
        end
      }
      if error_repos.length > 0
        Workspace.show_error(error_repos)
      else
        Output.puts_succeed_cmd(argv.absolute_cmd)
      end
    end

    def do_stash_pop_apply(argv, stash_name, action)
      do_repos = []
      mutex = Mutex.new
      Output.puts_processing_message("检查仓库状态...")
      all_repos.each { |repo|
        stash_list = repo_stash_list_msg(repo)
        next if stash_list.nil?

        stash_id = stash_include_name(stash_list, stash_name)
        next if stash_id.nil?
        mutex.lock
        do_repos.push(repo)
        mutex.unlock
      }
      Output.puts_success_message("检查完成！\n")

      Output.puts_start_cmd
      if do_repos.length == 0
        Output.puts_nothing_to_do_cmd
      else
        _, error_repos = Workspace.execute_common_cmd_with_repos('', do_repos) { |repo|
          stash_list = repo_stash_list_msg(repo)
          stash_id = stash_include_name(stash_list, stash_name)
          "git stash #{action} #{stash_id}"
        }
        Output.puts_succeed_cmd(argv.absolute_cmd) if error_repos.length == 0
      end
    end

    def do_stash_push(argv, stash_name)
      do_repos = []
      remind_repos = []
      mutex = Mutex.new
      Output.puts_processing_message("检查仓库状态...")
      all_repos.each { |repo|
        next if repo.status_checker.status == Repo::Status::GIT_REPO_STATUS[:clean]
        next if repo.status_checker.dirty_zone == Repo::Status::GIT_REPO_STATUS_DIRTY_ZONE[:special]

        stash_list = repo_stash_list_msg(repo)
        stash_id = stash_include_name(stash_list, stash_name)
        mutex.lock
        if stash_id.nil?
          do_repos.push(repo)
        else
          remind_repos.push(repo.name)
        end
        mutex.unlock
      }
      Output.puts_success_message("检查完成！\n")

      if remind_repos.length > 0
        Output.puts_remind_block(remind_repos, "以上仓库当前分支已经存在stash名称：#{stash_name}，请换一个名称或者使用\"mgit stash --list\"查看详情。")
        Output.puts_fail_cmd(argv.absolute_cmd)
      elsif do_repos.empty?
        Output.puts_remind_message("所有仓库均是clean状态或者文件未跟踪，无需执行")
      else
        Output.puts_start_cmd
        abs_cmd = "git stash save -u #{stash_name}"
        _, error_repos = Workspace.execute_common_cmd_with_repos(abs_cmd, do_repos)
        Output.puts_succeed_cmd(argv.absolute_cmd) if error_repos.length == 0
      end
    end

    # 获取当前的 stash list 字符串,nil,标识当前没有stash
    def repo_stash_list_msg(repo)
      success, output = repo.execute("git -C \"#{repo.path}\" stash list")
      return output if success && output.length > 0
    end

    # 查询stash_list 是否包含某一个保存的stash
    # 不做分支判断，因为在保存的stashlist中，分支只保留了/之后的内容
    #
    def stash_include_name(stash_list, stash_name)
      return if stash_list.nil?

      stash_list_array = stash_list.split("\n")

      find_stash_id = nil
      stash_list_array.each do |line|
        regex = /(stash@{\d+}):.*:\s(.*)$/
        next unless line.match(regex)
        match_stash_name = $2
        next unless match_stash_name == stash_name
        find_stash_id = $1
        break
      end
      find_stash_id
    end

    def enable_repo_selection
      true
    end

    def self.description
      "使用git stash将当前工作区改动暂时存放起来。"
    end

    def self.usage
      "mgit stash [<option> <value>...] [(--mrepo|--el-mrepo) <repo>...] [--help]"
    end

  end

end
