#coding=utf-8
#

require 'm-git/command_manager'

module MGit
  class BaseCommand

    def self.inherited(sub_klass)
      CommandManager.register_command(sub_klass.cmd, sub_klass)
    end

    # 当前命令行的命令比如checkout / status /..
    def self.cmd
      name.split('::').last.downcase
    end

    # 引入所有自定义指令
    Dir[File.join(__dir__, 'command', '*.rb')].each { |cmd|
      require cmd
    }

    HIGH_PRIORITY_OPT_LIST = {
      :help         =>  '--help',
      :help_s       =>  '-h',
      :auto_exec    => '--auto-exec'
    }.freeze

    # 注意使用时跟指令自身设置的参数对比，避免冲突
    SELECTABLE_OPT_LIST = {
      :mrepo            =>  '--mrepo',
      :mrepo_s          =>  '-m',
      :exclude_mrepo    =>  '--el-mrepo',
      :exclude_mrepo_s  =>  '-e',
      :include_lock     =>  '--include-lock',
      :include_lock_s   =>  '-i',
      :continue         =>  '--continue',
      :abort            =>  '--abort',
    }.freeze

    # 初始化
    #
    # @param argv [ARGV::Opt] 输入参数对象
    #
    def initialize(argv)
      # 指令解析
      setup_argv(argv)
      process_highest_priority_option(argv)
      validate(argv)
      @argv = argv
    end

    #--- 禁止覆写 ---
    # 执行主方法
    def run
      begin
        __config_repo_filter
        pre_exec
        execute(@argv)
        post_exec
      rescue SystemExit, Interrupt
        did_interrupt
      end
    end
    #---------------
    # Workspace Bridge
    def all_repos(except_config:false)
      Workspace.all_repos(except_config: except_config)
    end

    def locked_repos
      Workspace.locked_repos
    end

    def exec_light_repos
      Workspace.exec_light_repos
    end

    def generate_config_repo
      Workspace.generate_config_repo
    end
    # -----------
    private
    def __config_repo_filter
      cfg = Workspace.filter_config
      cfg.include_lock = !@argv.opt(SELECTABLE_OPT_LIST[:include_lock]).nil? || include_lock_by_default
      cfg.select_repos = @argv.opt(SELECTABLE_OPT_LIST[:mrepo])
      cfg.exclude_repos = @argv.opt(SELECTABLE_OPT_LIST[:exclude_mrepo])
      cfg.auto_exec = @argv.opt_list.did_set_opt?(HIGH_PRIORITY_OPT_LIST[:auto_exec])
    end
    #--- 基类调用，禁止覆写 ---
    # 配置参数对象
    def setup_argv(argv)
      argv.register_opts(options)
      argv.resolve!

      argv.opt_list.opts.each do |opt|
        next if opt.empty?
        revise_option_value(opt)
      end
    end

    # 处理最高优指令
    def process_highest_priority_option(argv)
      if argv.opt_list.did_set_opt?(HIGH_PRIORITY_OPT_LIST[:help])
        usage(argv)
        exit
      end
    end

    #-------------------------------------------------------

    #--- 可选覆写 ---
    # 此处有pre hook，覆写时需要先调用super, 特殊指令除外
    def pre_exec
      # 开始计时
      MGit::DurationRecorder.start
      # 配置根目录
      Workspace.setup_multi_repo_root

      # 配置log
      MGit::Loger.config(Workspace.root)
      MGit::Loger.info("~~~ #{@argv.absolute_cmd} ~~~")

      # 执行前置hook
      HooksManager.execute_mgit_pre_hook(@argv.cmd, @argv.pure_opts)

      # 解析配置文件
      Workspace.setup_config

      # 校验实体仓库
      Workspace.setup_all_repos
    end

    # 此处有post hook，覆写时需要最后调用super, 特殊指令除外
    def post_exec
      # 执行后置hook
      HooksManager.execute_mgit_post_hook(@argv.cmd, @argv.pure_opts, Workspace.exec_light_repos)
      # 打点结束
      duration = MGit::DurationRecorder.end
      MGit::Loger.info("~~~ #{@argv.absolute_cmd}, 耗时：#{duration} s ~~~")
    end

    # 【子类按需覆写修改返回值】返回true表示可以支持自动执行
    def enable_auto_execution
      false
    end

    # 【子类按需覆写修改返回值】返回true表示可以支持"--mrepo"等可选选项
    def enable_repo_selection
      false
    end

    # 【子类按需覆写修改返回值】是否使默认添加选项（如‘--help’）和可选添加的选项（如‘--mrepo’）支持短指令
    def enable_short_basic_option
      false
    end

    # 【子类按需覆写修改返回值】是否添加操作lock仓库的选项（如‘--include-lock’）
    def enable_lock_operation
      false
    end

    # 【子类按需覆写修改返回值】是否自动将lock仓库加入到操作集中
    def include_lock_by_default
      false
    end

    # 【子类按需覆写修改返回值】是否添加‘--continue’参数，要在指令中自行控制中间态操作
    def enable_continue_operation
      false
    end

    # 【子类按需覆写修改返回值】是否添加‘--abort’参数
    def enable_abort_operation
      false
    end

    # 【子类按需覆写修改实现】按下ctrl+c后调用
    def did_interrupt
    end

    # 可覆写该方法，返回该指令的描述
    def self.description
    end

    # 可覆写该方法，返回该指令的用法
    def self.usage
    end
    #---------------

    #--- 强制覆写 ---
    # 子类指令执行主方法
    def execute(argv)
      Foundation.help!("请覆写父类方法: \"execute(argv)\"")
    end
    #---------------

    #--- 如果要接管某个指令（即为它添加自定义参数） ---
    # --- 强制覆写（若该指令不带任何自定义参数，则无须覆写） ---
    # 注册选项，覆写时注意返回"[...].concat(super)"
    def options
      opts = [
          ARGV::Opt.new(HIGH_PRIORITY_OPT_LIST[:help],
                        short_key:(HIGH_PRIORITY_OPT_LIST[:help_s] if enable_short_basic_option),
                        info:"显示帮助。",
                        type: :boolean)
      ]

      opts.push(
          ARGV::Opt.new(HIGH_PRIORITY_OPT_LIST[:auto_exec],
                        info:'指定该参数会跳过所有交互场景，并自动选择需要的操作执行。该参数主要用于脚本调用mgit进行自动化操作，日常RD开发不应当使用。',
                        type: :boolean)
      ) if enable_auto_execution

      opts.push(
          ARGV::Opt.new(SELECTABLE_OPT_LIST[:mrepo],
          short_key:(SELECTABLE_OPT_LIST[:mrepo_s] if enable_short_basic_option),
          info:'指定需要执行该指令的仓库，可指定一个或多个，空格隔开，大小写均可，如："--mrepo boxapp BBAAccount"，若缺省则对所有仓库执行指令。'),
          ARGV::Opt.new(SELECTABLE_OPT_LIST[:exclude_mrepo],
          short_key:(SELECTABLE_OPT_LIST[:exclude_mrepo_s] if enable_short_basic_option),
          info:'指定不需要执行该指令的仓库，可指定一个或多个，空格隔开，大小写均可，如："--el-mrepo boxapp BBAAccount"，若缺省则对所有仓库执行指令。与"--mrepo"同时指定时无效。')
      ) if enable_repo_selection

      opts.push(
          ARGV::Opt.new(SELECTABLE_OPT_LIST[:include_lock], info:'指定该参数意味着同时也操作lock仓库。',
                        type: :boolean)
      ) if enable_lock_operation

      opts.push(
          ARGV::Opt.new(SELECTABLE_OPT_LIST[:continue],
                        info:'MGit自定义参数，仅在操作多仓库过程中出现问题停止，执行状态进入中间态后可用。该参数只能单独使用，解决问题后可执行"mgit <cmd> --continue"继续操作其余仓库。',
                        type: :boolean)
      ) if enable_continue_operation

      opts.push(
          ARGV::Opt.new(SELECTABLE_OPT_LIST[:abort],
                        info:'MGit自定义参数，仅在操作多仓库过程中出现问题停止，执行状态进入中间态后可用。该参数用于清除操作中间态，且只能单独使用："mgit <cmd> --abort"。',
                        type: :boolean)
      ) if enable_abort_operation

      opts
    end

    # 解析参数并更新参数值到列表中
    def revise_option_value(opt)
    end

    # --- 可选覆写（若该指令不带任何自定义参数，则无须覆写） ---
    # 判断是否有必须参数漏传或数据格式不正确
    def validate(argv)
    end

    # mgit是否输入--continue希望继续上次操作
    def mgit_try_to_continue?
      @argv.opt_list.did_set_opt?(SELECTABLE_OPT_LIST[:continue])
    end

    def mgit_try_to_abort?
      @argv.opt_list.did_set_opt?(SELECTABLE_OPT_LIST[:abort])
    end

    # 显示指令使用信息
    def usage(argv)
      puts "#{Output.blue_message("[指令说明]")}\n#{self.class.description}"
      puts "\n#{Output.blue_message("[指令格式]")}\n#{self.class.usage}"
      argv.show_info
    end

  end
end
