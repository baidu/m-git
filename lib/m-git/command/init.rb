#coding=utf-8

module MGit

  # @!scope 初始化多仓库命令
  #
  class Init < BaseCommand

    OPT_LIST = {
      :git_source       =>  '--git-source',
      :git_source_s     =>  '-g',
      :config_source    =>  '--config-source',
      :config_source_s  =>  '-f',
      :branch           =>  '--branch',
      :branch_s         =>  '-b',
      :local_config     =>  '--local-config',
      :local_config_s   =>  '-l',
      :all              =>  '--all',
      :all_s            =>  '-a'
    }.freeze

    def options
      return [
          ARGV::Opt.new(OPT_LIST[:git_source],
                        short_key:OPT_LIST[:git_source_s],
                        info:'通过包含多仓库配置表的git仓库来初始化，传入远程仓库地址，如："mgit init -g https://someone@bitbucket.org/someone"。不可与"-f"，"--config-source"同时指定。',
                        type: :string),
          ARGV::Opt.new(OPT_LIST[:config_source],
                        short_key:OPT_LIST[:config_source_s],
                        info:'通过本地的多仓库配置表来初始化，传入本地配置文件路径，如："mgit init -f <local_config_path>/manifest.json"。不可与"-g"，"--git-source"同时指定。',
                        type: :string),
          ARGV::Opt.new(OPT_LIST[:branch],
                        short_key:OPT_LIST[:branch_s],
                        info:'指定配置仓库克隆分支。',
                        type: :string),
          ARGV::Opt.new(OPT_LIST[:local_config],
                        short_key:OPT_LIST[:local_config_s],
                        info:'指定是否自动生成本地配置文件模版。指定后会在主仓库下生成名为local_manifest.json的本地配置文件，其内容只包含主仓库信息，并指定其余仓库不纳入mgit管理。初始化时指定该参数将只下载主仓库，若同时指定了"-a"或"--all"，则其余仓库也会被下载。',
                        type: :boolean),
          ARGV::Opt.new(OPT_LIST[:all],
                        short_key:OPT_LIST[:all_s],
                        info:'指定后会下载所有在配置表中配置了远程地址的仓库，无论该仓库是否被纳入mgit管理（无论是否指定"mgit_excluded:true"）。',
                        type: :boolean)
      ].concat(super)
    end

    def validate(argv)
      Foundation.help!("输入非法参数：#{argv.git_opts}") if argv.git_opts.length > 0

      git_source_opt = argv.opt(OPT_LIST[:git_source])
      file_source_opt = argv.opt(OPT_LIST[:config_source])
      if !git_source_opt.nil? && !file_source_opt.nil?
        Foundation.help!("不能同时指定参数\"#{OPT_LIST[:git_source]}\"和\"#{OPT_LIST[:config_source]}!\"")
      elsif git_source_opt.nil? && file_source_opt.nil?
        Foundation.help!("缺失参数\"#{OPT_LIST[:git_source]}\"或\"#{OPT_LIST[:config_source]}!\"")
      end
    end

    # --- 覆写前后hook，不需要预设操作 ---
    def pre_exec
      Output.puts_processing_message("开始初始化多仓库...")
      # 开始计时
      MGit::DurationRecorder.start

      initial_multi_repo_root

      # 配置log
      MGit::Loger.config(Workspace.root)
      MGit::Loger.info("~~~ #{@argv.absolute_cmd} ~~~")
    end

    def post_exec
      Output.puts_success_message("多仓库初始化成功！")
      # 打点结束
      duration = MGit::DurationRecorder.end
      MGit::Loger.info("~~~ #{@argv.absolute_cmd}, 耗时：#{duration} s ~~~")
    end

    # --------------------------------

    def execute(argv)
      init_dir

      begin
        git_url_opt = argv.opt(OPT_LIST[:git_source])
        local_url_opt = argv.opt(OPT_LIST[:config_source])
        clone_all = argv.opt_list.did_set_opt?(OPT_LIST[:all])
        if !git_url_opt.nil?
          git_url = git_url_opt.value
          branch = argv.opt(OPT_LIST[:branch]).value if argv.opt_list.did_set_opt?(OPT_LIST[:branch])
          use_local = argv.opt_list.did_set_opt?(OPT_LIST[:local_config])
          clone_with_git_url(git_url, branch, use_local, clone_all)
        elsif !local_url_opt.nil?
          clone_with_local_config(local_url_opt.value, clone_all)
        end
      rescue Interrupt => e
        terminate!(e.message)
      end
    end

    def init_dir
      Constants::PROJECT_DIR.each { |key, relative_dir|
        abs_dir = File.join(Workspace.root, relative_dir)
        FileUtils.mkdir_p(abs_dir)
        if key == :hooks
          setup_hooks(File.join(abs_dir, Constants::HOOK_NAME[:pre_hook]),
          File.join(abs_dir, Constants::HOOK_NAME[:post_hook]),
          File.join(abs_dir, Constants::HOOK_NAME[:manifest_hook]),
          File.join(abs_dir, Constants::HOOK_NAME[:post_download_hook]))
        end
      }
    end

    def write_content(path, content)
      file = File.new(path, 'w')
      if !file.nil?
        file.write(content)
        file.close
      end
    end

    def setup_hooks(pre_hook_path, post_hook_path, manifest_hook_path, post_download_hook)
      write_content(pre_hook_path, Template::PRE_CUSTOMIZED_HOOK_TEMPLATE)
      write_content(post_hook_path, Template::POST_CUSTOMIZED_HOOK_TEMPLATE)
      write_content(manifest_hook_path, Template::MANIFEST_HOOK_TEMPLATE)
      write_content(post_download_hook, Template::POST_DOWNLOAD_HOOK_TEMPLATE)
    end

    def initial_multi_repo_root

      if exist_root = Workspace.multi_repo_root_path
        Foundation.help!("当前已在多仓库目录下，请勿重复初始化！\n`#{exist_root}`")
      end

      @origin_root = Dir.pwd
      tmp_root = Utils.generate_init_cache_path(@origin_root)
      FileUtils.mkdir_p(tmp_root)
      Workspace.setup_multi_repo_root(tmp_root)
    end

    def setup_local_config(path, config_repo, use_local)
      if use_local
        content = Template.local_config_template(config_repo)
      else
        content = Template.default_template
      end

      write_content(path, content)
      Utils.link(path, File.join(Workspace.root, Constants::PROJECT_DIR[:source_config], Constants::CONFIG_FILE_NAME[:local_manifest]))
    end

    def clone_with_git_url(git_url, branch, use_local, clone_all)
      # 先将主仓库clone到mgit root目录下
      central_repo_temp_path = File.join(Workspace.root, Constants::CENTRAL_REPO)
      Output.puts_processing_message("正在克隆主仓库...")
      Utils.execute_shell_cmd("git clone -b #{branch.nil? ? 'master' : branch} -- #{git_url} #{central_repo_temp_path}") { |stdout, stderr, status|
        if status.success?
          # 获取主仓库中的配置文件
          begin
            config = Manifest.parse(central_repo_temp_path, strict_mode:false)
          rescue Error => e
            terminate!(e.msg)
          end
          central_light_repo = config.config_repo
          terminate!("配置文件中未找到主仓库配置，请添加后重试！") if central_light_repo.nil?
          terminate!("配置文件中主仓库url与传入的url不一致, 请处理后重试！") if git_url != central_light_repo.url

          central_repo_dest_path = central_light_repo.abs_dest(Workspace.root)

          # 如果不是子目录则删除已有
          if Dir.exist?(central_repo_dest_path) && !central_repo_temp_path.include?(central_repo_dest_path)
            FileUtils.remove_dir(central_repo_dest_path, true)
          end
          FileUtils.mkdir_p(central_repo_dest_path)
          mv_cmd = "mv #{central_repo_temp_path + '/{*,.[^.]*}'} #{central_repo_dest_path}"

          `#{mv_cmd}`
          FileUtils.rm_rf(central_repo_temp_path)

          # 链接.git实体
          Utils.link_git(central_repo_dest_path, central_light_repo.git_store_dir(Workspace.root))
          Output.puts_success_message("主仓库克隆完成！")

          # 链接本地配置文件
          setup_local_config(File.join(central_repo_dest_path, Constants::CONFIG_FILE_NAME[:local_manifest]), central_light_repo.name, use_local)

          # 由于更新了名字和可能的位置移动，重新解析配置文件
          begin
            config = Manifest.parse(central_repo_dest_path, strict_mode:false)
          rescue Error => e
            terminate!(e.msg)
          end

          # clone其余仓库
          clone_sub_repos(config.repo_list(exclusion:[config.config_repo.name], all:clone_all), branch)
          finish_init(config)
        else
          terminate!("主仓库克隆失败，初始化停止，请重试：\n#{stderr}")
        end
      }
    end

    def clone_with_local_config(config_path, clone_all)
      terminate!("指定路径\"#{config_path}\"文件不存在！") if !File.exist?(config_path)

      begin
        config = Manifest.parse(Utils.expand_path(config_path), strict_mode:false)
      rescue Error => e
        terminate!(e.msg)
      end

      if !config.config_repo.nil?
        clone_list = config.repo_list(exclusion: [config.config_repo.name], all:clone_all)
      else
        clone_list = config.repo_list(all:clone_all)
      end

      clone_sub_repos(clone_list, 'master')
      finish_init(config)
    end

    def clone_sub_repos(repo_list, default_branch)
      if repo_list.length != 0
        Output.puts_processing_message("正在克隆子仓库...")
        try_repos = repo_list
        retry_repos = []
        error_repos = {}

        mutex = Mutex.new
        mutex_progress = Mutex.new

        task_count = 0
        total_try_count = 4
        total_retry_count = total_try_count - 1
        # 保证失败仓库有3次重新下载的机会
        total_try_count.times { |try_count|
          Workspace.concurrent_enumerate(try_repos) { |light_repo|
            # 如果mainfest中指定了分支，就替换default branch
            branch = light_repo.branch ? light_repo.branch : default_branch
            Utils.execute_shell_cmd(light_repo.clone_url(Workspace.root, clone_branch:branch)) { |stdout, stderr, status|
              repo_dir = light_repo.abs_dest(Workspace.root)
              if status.success?
                Utils.link_git(repo_dir, light_repo.git_store_dir(Workspace.root))

                mutex_progress.lock
                task_count += 1
                Output.puts_success_message("(#{task_count}/#{try_repos.length}) \"#{light_repo.name}\"克隆完成！")
                mutex_progress.unlock
              else
                Output.puts_remind_message("\"#{light_repo.name}\"克隆失败，已加入重试队列。") if try_count < total_retry_count
                mutex.lock
                retry_repos.push(light_repo)
                error_repos[light_repo.name] = stderr
                FileUtils.remove_dir(repo_dir, true) if Dir.exist?(repo_dir)
                mutex.unlock
              end
            }
          }

          if retry_repos.length == 0 || try_count >= total_retry_count
            break
          else
            Output.puts_processing_block(error_repos.keys, "以上仓库克隆失败，开始第#{try_count + 1}次重试(最多#{total_retry_count}次)...")
            try_repos = retry_repos
            retry_repos = []
            error_repos = {}
            task_count = 0
          end
        }

        if error_repos.length > 0
          Workspace.show_error(error_repos)
          terminate!("初始化停止，请重试！")
        end
      end
    end

    def link_config(config_path, config_cache_path, root)
      Utils.execute_under_dir("#{File.join(root, Constants::PROJECT_DIR[:source_config])}") {
        # 在.mgit/source-config文件夹下创建原始配置文件的软连接
        config_link_path = File.join(Dir.pwd, Constants::CONFIG_FILE_NAME[:manifest])
        Utils.link(config_path, config_link_path) if config_path != config_link_path

        # 将配置缓存移动到.mgit/source-config文件夹下
        FileUtils.mv(config_cache_path, Dir.pwd) if File.dirname(config_cache_path) != Dir.pwd
      }
    end

    def terminate!(msg)
      Output.puts_fail_message(msg)
      Output.puts_processing_message("删除缓存...")
      FileUtils.remove_dir(Workspace.root, true) if Dir.exist?(Workspace.root)
      Output.puts_success_message("删除完成！")
      exit
    end

    def move_project_to_root
      Dir.foreach(Workspace.root) { |item|
        if item != '.' && item != '..' && item != '.DS_Store'
          FileUtils.mv(File.join(Workspace.root, item), @origin_root)
        end
      }
      FileUtils.remove_dir(Workspace.root, true) if Dir.exist?(Workspace.root)
    end

    def finish_init(config)
      move_project_to_root
      config_path, config_cache_path = config.path.sub(Workspace.root, @origin_root), config.cache_path.sub(Workspace.root, @origin_root)
      link_config(config_path, config_cache_path, @origin_root)
    end

    def enable_short_basic_option
      true
    end

    def self.description
      "初始化多仓库目录。"
    end

    def self.usage
      "mgit init (-f <path> | -g <url> [-b <branch>] [-l]) [-a]"
    end
  end
end
