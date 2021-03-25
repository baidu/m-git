#coding=utf-8

module MGit

  # 该指令用于不带指令的输入：mgit --help，用于执行mgit的一级参数（如"mgit --help"的"--help"）
  #
  class Self < BaseCommand

    HELP_INTRODUCTION = <<INTRO
#{Output.info_title("Description:")}

     mgit是多仓库管理工具，通过将git指令作用到多个仓库，实现批量的版本管理功能

     更多介绍：https://github.com/baidu/mgit

INTRO

    OPT_LIST = {
      :all            =>  '--all',
      :all_s          =>  '-a',
      :list           =>  '--list',
      :list_s         =>  '-l',
      :size           =>  '--size',
      :size_s         =>  '-s',
      :version        =>  '--version',
      :version_s      =>  '-v',
      :workspace      =>  '--workspace',
      :workspace_s    =>  '-w'
    }.freeze

    def options
      return [
          ARGV::Opt.new(OPT_LIST[:list], short_key:OPT_LIST[:list_s], info:"显示MGit管理的仓库。", type: :boolean),
          ARGV::Opt.new(OPT_LIST[:size], short_key:OPT_LIST[:size_s], info:"显示MGit管理的仓库的磁盘占用量。", type: :boolean),
          ARGV::Opt.new(OPT_LIST[:all], short_key:OPT_LIST[:all_s], info:"指定操作所有定义在manifest内的仓库，可配合-l合并使用: \"mgit -al\"。", type: :boolean),
          ARGV::Opt.new(OPT_LIST[:version], short_key:OPT_LIST[:version_s], info:"显示当前MGit版本。", type: :boolean),
          ARGV::Opt.new(OPT_LIST[:workspace], short_key:OPT_LIST[:workspace_s], info:"显示当前MGit工程管理根目录(.mgit所在目录)。", type: :boolean)
      ].concat(super)
    end

    def validate(argv)
      Foundation.help!("输入非法参数：#{argv.git_opts}。请通过\"mgit --help\"查看用法。") if argv.git_opts.length > 0
    end

    def prepare
      Workspace.setup_multi_repo_root
      Workspace.setup_config
    end

    # --- 覆写，不需要预设操作 ---
    def pre_exec
    end

    def post_exec
    end

    def usage(argv)
      show_help(argv)
    end
    # -------------------------

    def execute(argv)
      # 如果存在多余（透传）指令则报错
      extra_opt_str = argv.git_opts
      if extra_opt_str.length > 0
        Output.puts_fail_message("输入无效参数：#{extra_opt_str}\n")
        show_help(argv)
        exit
      end

      argv.enumerate_valid_opts { |opt|
        if opt.key == OPT_LIST[:list] || opt.key == OPT_LIST[:list_s]
          show_all_repos(argv)
          return
        elsif opt.key == OPT_LIST[:size] || opt.key == OPT_LIST[:size_s]
          show_repo_size
          return
        elsif opt.key == OPT_LIST[:version] || opt.key == OPT_LIST[:version_s]
          show_version
          return
        elsif opt.key == OPT_LIST[:workspace] || opt.key == OPT_LIST[:workspace_s]
          show_workspace
          return
        end
      }

      # 无任何参数传入时显示帮助
      show_help(argv)
    end

    def show_help(argv)
      head_space = '    '
      middle_space = '   '

      output =  HELP_INTRODUCTION # "#{Output.info_title("Description:")}\n\n#{head_space}mgit是多仓库管理工具，通过将git指令作用到多个仓库，实现批量的版本管理功能。"
      output += "#{Output.info_title("Usage:")}\n\n#{head_space}$ #{Output.green_message("mgit <mgit_options>")}\n"
      output += "#{head_space}$ #{Output.green_message("mgit <command> [<command_option>...] [<value>...]")}\n\n"

      # mgit options
      output += "#{Output.info_title("MGit Option:")}\n\n"
      divider = ", "
      longest_opt = argv.opt_list.opts.max_by { |e| "#{Output.blue_message("#{e.key}#{divider + e.short_key if !e.short_key.nil?}")}".length }
      max_opt_length = "#{longest_opt.short_key + divider + longest_opt.key}".length
      mgit_option_info = ''
      argv.opt_list.opts.each { |opt|
        key = "#{opt.short_key + divider + opt.key}"
        mgit_option_info += "#{head_space}#{Output.blue_message(key)}#{' ' * (max_opt_length - key.length + middle_space.length)}#{argv.info(opt.key)}\n"
      }
      output += mgit_option_info + "\n"

      # subcommand
      output += "#{Output.info_title("Command:")}\n\n"
      cmd_header = '+ '
      cmd_info = ''

      max_cmd_length = Output.blue_message(cmd_header + CommandManager.commands.keys.max_by { |e| e.length }.to_s).length
      CommandManager.commands.keys.sort.each { |cmd_name|
        next if cmd_name == self.class.cmd
        cls_name = CommandManager.commands[cmd_name]
        cmd_name = Output.green_message(cmd_header + cmd_name.downcase.to_s)
        cmd_info += "#{head_space}#{cmd_name}#{' ' * (max_cmd_length - cmd_name.length + middle_space.length)}#{cls_name.description}\n"
      }
      output += cmd_info + "\n"
      output += "#{Output.info_title("Command Option:")}\n\n#{head_space}请通过[ mgit <command> --help ]查看。\n\n"
      output += "#{Output.info_title("Version:")}\n\n#{head_space}#{MGit::VERSION}\n"

      puts output
    end

    def show_all_repos(argv)
      prepare

      list_all = argv.opt_list.did_set_opt?(OPT_LIST[:all])
      existing_repos, missing_repos = prepare_repos(with_excluded:list_all)

      list = {}
      if existing_repos.length > 0
        existing_repos.sort_by { |e| e.name }.each { |light_repo|
          dir = File.join("<ROOT>", File.dirname(light_repo.path)).bold
          list[dir] = [] if list[dir].nil?
          list[dir].push(light_repo.name)
        }
      end

      if missing_repos.length > 0
        list['本地缺失'.bold] = missing_repos.sort_by { |e| e.name }.map { |e| e.name }
      end

      list_array = []
      list.each { |dir, list|
        list_array.push([dir.bold, list])
      }

      puts Output.generate_table_combination(list_array, separator:'|')
      if list_all
        message = "共统计#{existing_repos.length + missing_repos.length}个仓库。"
      else
        message = "mgit目前共管理#{existing_repos.length + missing_repos.length}个仓库。"
      end
      Output.puts_remind_message(message)
      Output.puts_fail_message("有#{missing_repos.length}个仓库本地缺失!") if missing_repos.length > 0
    end

    def show_repo_size
      prepare
      Workspace.setup_all_repos
      Output.puts_processing_message("开始计算...")
      repo_size = {}
      mutex = Mutex.new
      task_count = 0
      Output.update_progress(all_repos.length, task_count)
      Workspace.concurrent_enumerate(all_repos) { |repo|
        success, output = repo.execute("du -sh #{repo.path}")
        mutex.lock
        if success
          repo_size[repo.name] = output&.strip
        end
        task_count += 1
        Output.update_progress(all_repos.length, task_count)
        mutex.unlock
      }
      Output.puts_success_message("计算完成。")

      display_size = repo_size.sort_by { |k,v| k}.map { |e| e.last }
      Output.puts_remind_block(display_size, "共统计#{repo_size.length}个仓库。")
    end

    def prepare_repos(with_excluded:false)
      existing_repos = []
      missing_repos = []
      Workspace.config.light_repos.each { |light_repo|
        if with_excluded || !light_repo.mgit_excluded
          repo_exist = Repo.is_git_repo?(light_repo.abs_dest(Workspace.root))
          if repo_exist
            existing_repos.push(light_repo)
          else
            missing_repos.push(light_repo)
          end
        end
      }
      return existing_repos, missing_repos
    end

    def show_workspace
      root = Workspace.multi_repo_root_path
      if root.nil?
        Output.puts_fail_message("当前不在任何多仓库目录下！")
      else
        puts root
      end
    end

    def show_version
      puts MGit::VERSION
    end

    def enable_short_basic_option
      return true
    end

  end

end
