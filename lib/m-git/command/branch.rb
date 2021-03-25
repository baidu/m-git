#coding=utf-8

module MGit

  # @!scope [command] branch
  # follow git branch
  # eg: mgit branch --compact
  #
  class Branch < BaseCommand

    OPT_LIST = {
      :compact    =>  '--compact',
    }.freeze

    def options
      [
          ARGV::Opt.new(OPT_LIST[:compact], info:"以归类的方式显示所有仓库的当前分支。", type: :boolean)
      ].concat(super)
    end

    def execute(argv)
      Output.puts_start_cmd

      if argv.opt(OPT_LIST[:compact])
        show_compact_branches(argv)
        return
      end

      # 无自定义参数则透传
      extcute_as_common(argv)
    end

    # 常规执行
    def extcute_as_common(argv)
      error_repos = {}
      all_repos.sort_by { |repo| repo.name }.each { |repo|
        success, output = repo.execute_git_cmd(argv.cmd, argv.git_opts)
        if success && output.length > 0
          puts Output.generate_title_block(repo.name) {
            output
          } + "\n"
        elsif !success
          error_repos[repo.name] = output
        end
      }
      if error_repos.length > 0
        Workspace.show_error(error_repos)
      else
        Output.puts_succeed_cmd(argv.absolute_cmd)
      end
    end

    # 以紧凑模式执行
    def show_compact_branches(argv)
      show_branches_for_repos(all_repos, false)
      show_branches_for_repos(locked_repos, true)
      Output.puts_succeed_cmd(argv.absolute_cmd)
    end

    # 紧凑地显示一组仓库分支
    def show_branches_for_repos(repos, locked)
      return if repos.nil?

      list = {}
      repos.sort_by { |repo| repo.name }.each { |repo|
        branch = repo.status_checker.current_branch(strict_mode:false)
        branch = 'HEAD游离，不在任何分支上！' if branch.nil?
        list[branch] = [] if list[branch].nil?
        list[branch].push(repo.name)
      }
      list.each { |branch, repo_names|
        Output.puts_remind_block(repo_names, "以上仓库的当前分支：#{branch}#{' [锁定]' if locked}")
        puts "\n"
      }
    end

    def enable_repo_selection
      true
    end

    def self.description
      "创建、显示、删除分支。"
    end

    def self.usage
      "mgit branch [<git-branch-option>|--compact] [(--mrepo|--el-mrepo) <repo>...] [--help]"
    end
  end

end
