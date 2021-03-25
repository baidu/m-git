#coding=utf-8

module MGit

  # @!scope [command] config 配置 .mgit/config.yml 文件信息
  #
  # eg: mgit config -s key 'value'
  #
  class Config < BaseCommand

    OPT_LIST = {
      :create_local          =>  '--create-local',
      :create_local_s        =>  '-c',
      :update_manifest       =>  '--update-manifest',
      :update_manifest_s     =>  '-m',
      :update_local          =>  '--update-local',
      :update_local_s        =>  '-u',
      :list                  =>  '--list',
      :list_s                =>  '-l',
      :set                   =>  '--set',
      :set_s                 =>  '-s'
    }.freeze

    def options
      return [
          ARGV::Opt.new(OPT_LIST[:update_manifest],
                        short_key:OPT_LIST[:update_manifest_s],
                        info:"该指令用于更新mgit所使用的配置文件，如：\"mgit config -m <new_path>/manifest.json\"。",
                        type: :boolean),
          ARGV::Opt.new(OPT_LIST[:update_local],
                        short_key:OPT_LIST[:update_local_s],
                        info:"该指令用于更新mgit所使用的本地配置文件，如：\"mgit config -u <new_path>/local_manifest.json\"。",
                        type: :boolean),
          ARGV::Opt.new(OPT_LIST[:create_local],
                        short_key:OPT_LIST[:create_local_s],
                        info:"在指定目录下创建本地配置文件，若目录不存在则自动创建。如执行：\"mgit config -c /a/b/c\"，则生成本地配置文件：\"/a/b/c/local_manifest.json\"。如果未传入值，如：\"mgit config -c\"，那么若配置仓库存在的话，会在配置仓库中创建本地配置文件。",
                        type: :string),
          ARGV::Opt.new(OPT_LIST[:list],
                        short_key:OPT_LIST[:list_s],
                        info:"列出当前MGit所有配置，无参数，如：\"mgit config -l\"。",
                        type: :boolean),
          ARGV::Opt.new(OPT_LIST[:set],
                        short_key:OPT_LIST[:set_s],
                        info:"对MGit进行配置，遵守格式：\"mgit config -s <key> <value>\"，如：\"mgit config -s maxconcurrentcount 5\"。")
      ].concat(super)
    end

    def validate(argv)
      Foundation.help!("输入非法参数：#{argv.git_opts}。请通过\"mgit #{argv.cmd} --help\"查看用法。") if argv.git_opts.length > 0

      if set_kv = argv.opt(OPT_LIST[:set])
        Foundation.help!("参数#{OPT_LIST[:set]}格式错误，只需传入key和value两个值！") if set_kv.value.count != 2
      end
    end

    # --- 覆写前后hook，不需要预设操作 ---
    def pre_exec
      # 开始计时
      MGit::DurationRecorder.start
      Workspace.setup_multi_repo_root
      # 配置log
      MGit::Loger.config(Workspace.root)
      MGit::Loger.info("~~~ #{@argv.absolute_cmd} ~~~")
    end

    def post_exec
      # 打点结束
      duration = MGit::DurationRecorder.end
      MGit::Loger.info("~~~ #{@argv.absolute_cmd}, 耗时：#{duration} s ~~~")
    end
    # --------------------------------

    def execute(argv)
      argv.enumerate_valid_opts { |opt|
        if opt.key == OPT_LIST[:update_manifest]
          update_mgit_config(opt.value)
          return
        elsif opt.key == OPT_LIST[:update_local]
          update_local_config(opt.value)
          return
        elsif opt.key == OPT_LIST[:create_local]
          dir = opt.value
          if opt.value.is_a?(TrueClass)
            Workspace.setup_config
            if Workspace.config.config_repo.nil?
              Foundation.help!("未找到配置仓库，请为参数\"--create-local\"或\"-c\"指定一个具体文件夹目录并重试！")
            else
              dir = Workspace.config.config_repo.abs_dest(Workspace.root)
            end
          end
          create_local_config(dir)
          return
        elsif opt.key == OPT_LIST[:list]
          dump_config
        elsif opt.key == OPT_LIST[:set]
          set_config(opt.value)
        end
      }
    end

    # 更新配置表软链接
    def update_mgit_config(config_path)
      config = Manifest.parse(Utils.expand_path(config_path))
      Utils.execute_under_dir("#{File.join(Workspace.root, Constants::PROJECT_DIR[:source_config])}") {
        mgit_managed_config_link_path = File.join(Dir.pwd, Constants::CONFIG_FILE_NAME[:manifest])
        mgit_managed_config_cache_path = File.join(Dir.pwd, Constants::CONFIG_FILE_NAME[:manifest_cache])

        # 在.mgit/source-config文件夹下创建原始配置文件的软连接
        if config.path != mgit_managed_config_link_path
          Utils.link(config.path, mgit_managed_config_link_path)
        end

        # 将配置缓存移动到.mgit/source-config文件夹下
        if config.cache_path != mgit_managed_config_cache_path
          FileUtils.rm_f(mgit_managed_config_cache_path) if File.exist?(mgit_managed_config_cache_path)
          FileUtils.mv(config.cache_path, Dir.pwd)
        end

        Output.puts_success_message("配置文件更新完毕！")
      }
    end

    # 更新本地配置表软链接
    def update_local_config(config_path)
      config_path = Utils.expand_path(config_path)
      Utils.execute_under_dir("#{File.join(Workspace.root, Constants::PROJECT_DIR[:source_config])}") {
        mgit_managed_local_config_link_path = File.join(Dir.pwd, Constants::CONFIG_FILE_NAME[:local_manifest])
        # 在.mgit/source-config文件夹下创建原始本地配置文件的软连接
        if config_path != mgit_managed_local_config_link_path
          Utils.link(config_path, mgit_managed_local_config_link_path)
        end

        Output.puts_success_message("本地配置文件更新完毕！")
      }
    end

    # 新建本地配置表软链接
    def create_local_config(dir)
      path = Utils.expand_path(File.join(dir, Constants::CONFIG_FILE_NAME[:local_manifest]))
      if File.exist?(path) && !Output.continue_with_user_remind?("本地配置文件\"#{path}\"已经存在，是否覆盖？")
        Output.puts_cancel_message
        return
      end

      FileUtils.mkdir_p(dir)
      file = File.new(path, 'w')
      if !file.nil?
        file.write(Template.default_template)
        file.close
      end

      Utils.link(path, File.join(Workspace.root, Constants::PROJECT_DIR[:source_config], Constants::CONFIG_FILE_NAME[:local_manifest]))
      Output.puts_success_message("本地配置文件生成完毕：#{path}")
    end

    # 列出所有配置
    def dump_config
      begin
        MGitConfig.dump_config(Workspace.root)
      rescue Error => e
        Foundation.help!(e.msg)
      end
    end

    # 设置配置
    def set_config(key_value_arr)
      key = key_value_arr.first
      value = key_value_arr.last
      begin
        MGitConfig.update(Workspace.root) { |config|
          if MGitConfig::CONFIG_KEY.keys.include?(key.to_sym)
            valid_value = MGitConfig.to_suitable_value_for_key(Workspace.root, key, value)
            if !valid_value.nil?
              config[key] = valid_value
            else
              type = MGitConfig::CONFIG_KEY[key.to_sym][:type]
              Foundation.help!("#{value}不匹配类型：#{type}，请重试。")
            end
          else
            Foundation.help!("非法key值：#{key}。使用mgit config -l查看所有可配置字段。")
          end
        }
        Output.puts_success_message("配置成功！")
      rescue Error => e
        Foundation.help!(e.msg)
      end
    end

    # 允许使用短命令
    def enable_short_basic_option
      true
    end

    def self.description
      "用于更新多仓库配置信息。"
    end

    def self.usage
      "mgit config [-s <config_key> <config_value>] [-l]\nmgit config [(-m|-u) <path_to_manifest> | -c <dir_contains_local>]\nmgit config [-h]"
    end
  end
end
