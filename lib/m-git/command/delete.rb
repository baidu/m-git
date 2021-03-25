#coding=utf-8

module MGit

  # @!scope [command] delete 删除某个仓库的`所有`文件，包括工作区、暂存区和版本库
  #
  # eg: mgit delete subA
  #
  class Delete < BaseCommand

    # --- 覆写前后hook，不需要预设操作 ---
    def pre_exec
      MGit::DurationRecorder.start
      Workspace.setup_multi_repo_root
      # 配置log
      MGit::Loger.config(Workspace.root)
      MGit::Loger.info("~~~ #{@argv.absolute_cmd} ~~~")
      Workspace.setup_config
    end

    def post_exec
      # 打点结束
      duration = MGit::DurationRecorder.end
      MGit::Loger.info("~~~ #{@argv.absolute_cmd}, 耗时：#{duration} s ~~~")
    end
    # --------------------------------

    def execute(argv)
      delete_repo_names = parse_repo_name(argv)
      include_central = Workspace.config.light_repos.find do |e|
        delete_repo_names.include?(e.name.downcase) && e.is_config_repo
      end
      Foundation.help!("禁止删除配置仓库=> #{include_central.name}") if include_central

      Output.puts_start_cmd
      delete_light_repos = Workspace.config.light_repos.select { |e| delete_repo_names.include?(e.name.downcase) }
      extra_repo_names = delete_repo_names - delete_light_repos.map { |e| e.name.downcase}
      if delete_light_repos.length > 0
        error_repos = {}
        delete_light_repos.each { |light_repo|
          begin
            git_dir = light_repo.git_store_dir(Workspace.root)
            repo_dir = light_repo.abs_dest(Workspace.root)
            if !Dir.exist?(git_dir) && !Dir.exist?(repo_dir)
              Output.puts_remind_message("#{light_repo.name}本地不存在，已跳过。")
            end

            # 删除git实体
            if Dir.exist?(git_dir)
              Output.puts_processing_message("删除仓库#{light_repo.name}的.git实体...")
              FileUtils.remove_dir(git_dir, true)
            end

            # 删除工作区文件
            if Dir.exist?(repo_dir)
              Output.puts_processing_message("删除仓库#{light_repo.name}工作区文件...")
              FileUtils.remove_dir(repo_dir, true)
            end
          rescue => e
            error_repos[light_repo.name] = e.message
          end
        }
        if error_repos.length > 0
          Workspace.show_error(error_repos)
        else
          Output.puts_succeed_cmd(argv.absolute_cmd)
        end
      end

      if extra_repo_names.length > 0
        Output.puts_fail_block(extra_repo_names, "以上仓库配置表中未定义，请重试！")
      end
    end

    def parse_repo_name(argv)
      return if argv.git_opts.nil?

      repos = argv.git_opts.split(' ')
      extra_opts = repos.select { |e| argv.is_option?(e) }
      Foundation.help!("输入非法参数：#{extra_opts.join('，')}。请通过\"mgit #{argv.cmd} --help\"查看用法。") if extra_opts.length > 0
      Foundation.help!("未输入查询仓库名！请使用这种形式查询：mgit info repo1 repo2 ...") if repos.length == 0
      repos.map { |e| e.downcase }
    end

    def enable_short_basic_option
      true
    end

    def self.description
      "删除指定单个或多个仓库（包含被管理的.git文件和工程文件以及跟该.git关联的所有缓存）。"
    end

    def self.usage
      "mgit delete <repo1> <repo2>... [-h]"
    end

  end

end
