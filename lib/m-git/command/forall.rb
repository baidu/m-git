#coding=utf-8

module MGit

  # @!scope [command] forall 对管理的仓库依次执行shell命令
  #
  # eg: mgit forall -c 'git status'
  #
  class Forall < BaseCommand

    OPT_LIST = {
      :command      => '--command',
      :command_s    => '-c',
      :concurrent   => '--concurrent',
      :concurrent_s => '-n',
    }.freeze

    def options
      return [
          ARGV::Opt.new(OPT_LIST[:command],
                        short_key:OPT_LIST[:command_s],
                        info:'必须参数，指定需要执行的shell命令，如："mgit forall -c \'git status -s\'"（注意要带引号）。',
                        type: :string),
          ARGV::Opt.new(OPT_LIST[:concurrent],
                        short_key:OPT_LIST[:concurrent_s],
                        info:'可选参数，若指定，则shell命令以多线程方式执行。',
                        type: :boolean)
      ].concat(super)
    end

    def validate(argv)
      Foundation.help!("输入非法参数：#{argv.git_opts}。请通过\"mgit #{argv.cmd} --help\"查看用法。") if argv.git_opts.length > 0
      Foundation.help!("请输入必须参数--command，示例：mgit forall -c 'git status'") if argv.opt(OPT_LIST[:command]).nil?
    end

    def execute(argv)
      # 校验分支统一
      Workspace.check_branch_consistency

      Output.puts_start_cmd
      for_all_cmd = argv.opt(OPT_LIST[:command]).value

      use_concurrent = !argv.opt(OPT_LIST[:concurrent]).nil?
      if use_concurrent
        succeed_repos, error_repos = Workspace.execute_common_cmd_with_repos_concurrent(for_all_cmd, all_repos)
      else
        succeed_repos, error_repos = Workspace.execute_common_cmd_with_repos(for_all_cmd, all_repos)
      end

      no_output_repos = []
      succeed_repos.each { |repo_name, output|
        if output.length > 0
          puts Output.generate_title_block(repo_name) { output } + "\n"
        else
          no_output_repos.push(repo_name)
        end
      }

      Output.puts_remind_block(no_output_repos, "以上仓库无输出！") if no_output_repos.length > 0
      Output.puts_succeed_cmd(argv.absolute_cmd) if error_repos.length == 0
    end

    def enable_repo_selection
      true
    end

    def enable_short_basic_option
      true
    end

    def self.description
      "对多仓库批量执行指令。"
    end

    def self.usage
      "mgit forall -c '<instruction>' [(-m|-e) <repo>...] [-n] [-h]"
    end

  end

end
