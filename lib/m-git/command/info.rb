#coding=utf-8

module MGit

  # @!scope 指定仓库的信息
  #
  class Info < BaseCommand

    def execute(argv)
      Output.puts_start_cmd

      query_repo_names = parse_repo_name(argv)
      quere_repos = (all_repos + locked_repos).select { |e| query_repo_names.include?(e.name.downcase) }
      if quere_repos.length > 0
        quere_repos.each { |repo|
          puts Output.generate_title_block(repo.name) {
            info = []
            info.push(['仓库位置'.bold, ["#{repo.path}"]])
            info.push(['占用磁盘大小'.bold, ["#{calculate_size(repo)}"]])
            info.push(['创建时间'.bold, ["#{File.ctime(repo.path)}"]])

            current_branch = repo.status_checker.current_branch(strict_mode:false)
            branch_message = repo.status_checker.branch_message
            info.push(['当前分支'.bold, ["#{current_branch.nil? ? '无' : current_branch}"]])
            info.push(['分支状态'.bold, ["#{branch_message}"]])

            info.push(['文件改动'.bold, ["#{repo.status_checker.status != Repo::Status::GIT_REPO_STATUS[:clean] ? '有本地改动,请用status指令查看细节' : '本地无修改'}"]])
            info.push(['Stash状态'.bold, ["#{check_stash(repo)}"]])
            Output.generate_table_combination(info) + "\n\n"
          }
        }
        Output.puts_succeed_cmd(argv.absolute_cmd)
      else
        Output.puts_fail_message("未找到与输入仓库名匹配的仓库，请重试！")
      end

    end

    def parse_repo_name(argv)
      return nil if argv.git_opts.nil?
      repos = argv.git_opts.split(' ')
      extra_opts = repos.select { |e| argv.is_option?(e) }
      Foundation.help!("输入非法参数：#{extra_opts.join('，')}。请通过\"mgit #{argv.cmd} --help\"查看用法。") if extra_opts.length > 0
      Foundation.help!("未输入查询仓库名！请使用这种形式查询：mgit info repo1 repo2 ...") if repos.length == 0
      repos.map { |e| e.downcase }
    end

    def calculate_size(repo)
      success, output = repo.execute("du -sh #{repo.path} | awk '{print $1}'")
      return '计算失败'.red unless success
      output.chomp
    end

    def check_stash(repo)
      success, output = repo.execute("git -C \"#{repo.path}\" stash list")
      return "查询失败".red unless success
      output.length > 0 ? '有内容' : '无内容'
    end

    def enable_short_basic_option
      false
    end

    def self.description
      "输出指定仓库的信息。"
    end

    def self.usage
      "mgit info <repo>... [-h]"
    end

  end

end
