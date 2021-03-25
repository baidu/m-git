#coding=utf-8

module MGit

  # @!scope 同步所有管理的仓库到工作区，可能从远端拉取，可能从本地dump，所以sync后的工作区不一定是分支的最新节点
  # 可通过 mgit sync --pull 进行同步后pull到最新节点
  #
  class Sync < BaseCommand

    OPT_LIST = {
      :new_repo    =>  '--new-repo',
      :new_repo_s  =>  '-n',
      :all         =>  '--all',
      :all_s       =>  '-a',
      :clone       =>  '--clone',
      :clone_s     =>  '-c',
      :pull        =>  '--pull',
      :pull_s      =>  '-p',
      :url         =>  '--url',
      :url_s       =>  '-u',
    }.freeze

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

    def options
      return [
          ARGV::Opt.new(OPT_LIST[:new_repo],
                        short_key:OPT_LIST[:new_repo_s],
                        info:"下载配置表中指定被mgit管理，但本地不存在的仓库，已有仓库不做任何处理，使用：mgit sync -n。",
                        type: :boolean),
          ARGV::Opt.new(OPT_LIST[:all],
                        short_key:OPT_LIST[:all_s],
                        info:'对所有(包含不被mgit管理的)仓库操作:1.如果本地缺失则下载。2.如果本地存在且被锁定则同步到锁定状态。注意，如果需要下载代码，需要配置仓库URL，否则跳过，使用：mgit sync -a。',
                        type: :boolean),
          ARGV::Opt.new(OPT_LIST[:clone], short_key:OPT_LIST[:clone_s], info:'下载一组仓库(包含不被mgit管理的仓库)，如: mgit sync -c repo1 repo2。'),
          ARGV::Opt.new(OPT_LIST[:pull],
                        short_key:OPT_LIST[:pull_s],
                        info:'同步本地仓库后执行pull操作更新，配合其他指令使用，如: mgit sync -a -p。',
                        type: :boolean),
          ARGV::Opt.new(OPT_LIST[:url],
                        short_key:OPT_LIST[:url_s],
                        info:'校验并同步URL与配置不一致的仓库，如: mgit sync -u。',
                        type: :boolean)
      ].concat(super)
    end

    def validate(argv)
      opt_all = argv.opt(OPT_LIST[:all])
      opt_clone = argv.opt(OPT_LIST[:clone])
      opt_new = argv.opt(OPT_LIST[:new_repo])
      invalid = [opt_all, opt_clone, opt_new].select { |e| !e.nil? }.length > 1
      Foundation.help!("请勿同时指定[#{OPT_LIST[:all]}|#{OPT_LIST[:all_s]}],[#{OPT_LIST[:clone]}|#{OPT_LIST[:clone_s]}]和[#{OPT_LIST[:new_repo]}|#{OPT_LIST[:new_repo_s]}]。") if invalid
    end

    def execute(argv)
      Output.puts_start_cmd

      if argv.opt_list.did_set_opt?(OPT_LIST[:all])
        setup_all_sync_reops(argv)
      elsif argv.opt_list.did_set_opt?(OPT_LIST[:new_repo])
        setup_new_reops
      elsif argv.opt_list.did_set_opt?(OPT_LIST[:url])
        setup_config_url_repos
      elsif argv.opt_list.did_set_opt?(OPT_LIST[:clone])
        return if !setup_download_reops(argv.opt(OPT_LIST[:clone]).value)
      elsif argv.git_opts.length > 0
        return if !setup_specified_repos(argv)
      else
        setup_normal_reops(argv)
      end

      if (@sync_repos.length + @update_repos.length + @download_repos.length) == 0
        Output.puts_success_message("没有仓库需要同步！")
        return
      end

      error_repos = {}
      if @sync_repos.length > 0
        Workspace.concurrent_enumerate_with_progress_bar(@sync_repos, "正在同步(锁定)以上仓库...") { |light_repo|
          repo = Repo.generate_strictly(Workspace.root, light_repo)
          error_message = Repo::SyncHelper.sync_exist_repo(repo, light_repo)
          if !error_message.nil?
            Lock.mutex_exec { error_repos[light_repo.name] = error_message }
          end
        }
      end

      if @update_repos.length > 0
        Workspace.concurrent_enumerate_with_progress_bar(@update_repos, "正在更新以上仓库...") { |light_repo|
          repo = Repo.generate_strictly(Workspace.root, light_repo)
          success, output = repo.execute_git_cmd('pull', '')
          if !success
            Lock.mutex_exec { error_repos[light_repo.name] = output }
          end
        }
      end

      if @download_repos.length > 0
        Workspace.sync_new_repos(@download_repos)
      end

      if error_repos.length > 0
        Workspace.show_error(error_repos)
      else
        Output.puts_succeed_cmd(argv.absolute_cmd)
      end
    end

    def prepare_repo_category
      @sync_repos = []
      @update_repos = []
      @download_repos = []
    end

    # M/NM: 被/不被mgit管理
    # E/NE: 仓库本地存在/不存在
    # L/NL: 仓库被/不被锁定
    # U/NU: 仓库有/没有远程地址

    # mgit sync repo1 repo2 ... [--pull]
    # 针对一组指定仓库进行：下载仓库：NE|U，同步仓库：E|L，更新仓库: E|U（可选）
    def setup_specified_repos(argv)
      prepare_repo_category
      should_pull = argv.opt_list.did_set_opt?(OPT_LIST[:pull])
      valid_repos, error_repo_names = check_valid_repos(parse_repo_name(argv))
      valid_repos.each { |light_repo|
        repo_exist = Dir.exist?(light_repo.abs_dest(Workspace.root))
        if !repo_exist
          if !light_repo.url.nil?
            @download_repos.push(light_repo)
          else
            error_repo_names.push(light_repo.name)
          end
        else
          if light_repo.lock
            @sync_repos.push(light_repo)
          end

          if should_pull
            if !light_repo.url.nil?
              @update_repos.push(light_repo)
            else
              error_repo_names.push(light_repo.name)
            end
          end
        end
      }

      should_continue = true
      error_repos = []
      error_repos.push(['配置表中未定义(或未指定"remote-path")', error_repo_names]) if error_repo_names.length > 0
      Output.interact_with_multi_selection_combined_repos(error_repos, "以上仓库状态异常", ['a: 跳过并继续', 'b: 终止']) { |input|
        if input == 'b'
          Output.puts_cancel_message
          should_continue = false
        end
      } if error_repos.length > 0
      return should_continue
    end

    # mgit sync [--pull]
    # 下载仓库：M|NE|U, 同步仓库：M|E|L, 更新仓库：M|E|U（可选）
    def setup_normal_reops(argv)
      prepare_repo_category
      should_pull = argv.opt_list.did_set_opt?(OPT_LIST[:pull])
      Workspace.config.light_repos.each { |light_repo|
        if !light_repo.mgit_excluded
          repo_exist = Dir.exist?(light_repo.abs_dest(Workspace.root))
          if !repo_exist && !light_repo.url.nil?
            @download_repos.push(light_repo)
          elsif repo_exist && light_repo.lock
            @sync_repos.push(light_repo)
          end

          if repo_exist && should_pull && !light_repo.url.nil?
              @update_repos.push(light_repo)
          end
        end
      }
    end

    # mgit sync --new
    # 下载仓库：M|NE|U
    def setup_new_reops
      prepare_repo_category
      Workspace.config.light_repos.each { |light_repo|
        if !light_repo.mgit_excluded
          repo_exist = Dir.exist?(light_repo.abs_dest(Workspace.root))
          @download_repos.push(light_repo) if !repo_exist && !light_repo.url.nil?
        end
      }
    end

    # mgit sync --all [--pull]
    # 下载仓库：NE|U，同步仓库：E|L，更新仓库: E|NL|U（可选）
    def setup_all_sync_reops(argv)
      prepare_repo_category
      Workspace.config.light_repos.each { |light_repo|
        repo_exist = Dir.exist?(light_repo.abs_dest(Workspace.root))
        if !repo_exist && !light_repo.url.nil?
          @download_repos.push(light_repo)
        elsif repo_exist && light_repo.lock
          @sync_repos.push(light_repo)
        elsif repo_exist && !light_repo.url.nil? && argv.opt_list.did_set_opt?(OPT_LIST[:pull])
          @update_repos.push(light_repo)
        end
      }
    end

    # mgit sync --clone repo1 repo2 ...
    # 下载仓库：NE|U(指定)
    def setup_download_reops(repo_names)
      prepare_repo_category
      existing_repos = []
      valid_repos, error_repo_names = check_valid_repos(repo_names)

      valid_repos.each { |light_repo|
        repo_exist = Dir.exist?(light_repo.abs_dest(Workspace.root))
        if !repo_exist
          if !light_repo.url.nil?
            @download_repos.push(light_repo)
          else
            error_repo_names.push(light_repo.name)
          end
        else
          error_repo_names.push(light_repo.name) if light_repo.url.nil?
          existing_repos.push(light_repo.name)
        end
      }

      should_continue = true
      error_repos = []
      error_repos.push(['配置表中未定义(或未指定"remote-path")', error_repo_names]) if error_repo_names.length > 0
      error_repos.push(['本地已经存在', existing_repos]) if existing_repos.length > 0
      Output.interact_with_multi_selection_combined_repos(error_repos, "以上仓库状态异常", ['a: 跳过并继续', 'b: 终止']) { |input|
        if input == 'b'
          Output.puts_cancel_message
          should_continue = false
        end
      } if error_repos.length > 0
      return should_continue
    end

    # mgit sync -u
    # 同步仓库：E | url不一致
    def setup_config_url_repos()
      prepare_repo_category

      warning_repos = []
      missing_repos = []
      Workspace.config.light_repos.each { |light_repo|
        if !light_repo.mgit_excluded
          repo, _ = Repo.generate_softly(Workspace.root, light_repo)
          if !repo.nil?
            original_url = repo.status_checker.default_url
            target_url = light_repo.url
            warning_repos.push(light_repo) if !Utils.url_consist?(original_url, target_url)
          else
            missing_repos.push(light_repo)
          end
        end
      }

      Output.puts_remind_block(missing_repos.map { |repo| repo.name }, "以上仓库本地缺失，无法校验URL，请执行\"mgit sync -n\"重新下载后重试！") if missing_repos.length > 0

      if warning_repos.length > 0
        if Output.continue_with_interact_repos?(warning_repos.map { |repo| repo.name }, "以上仓库的当前URL(origin)和配置表指定URL不一致，建议\n     1. 执行\"mgit delete repo1 repo2...\"删除仓库.\n     2. 执行\"mgit sync -n\"重新下载。\n    继续强制设置可能导致仓库出错，是否继续？")
          @sync_repos = warning_repos
        else
          Output.puts_cancel_message
          exit
        end
      end
    end

    def check_valid_repos(repo_names)
      specified_repos = repo_names.map { |name| name.downcase }
      all_valid_repos = Workspace.config.light_repos.map { |light_repo| light_repo.name.downcase }
      error_repo_names = specified_repos - all_valid_repos
      valid_repo_names = specified_repos - error_repo_names
      valid_repos = Workspace.config.light_repos.select { |light_repo|
        valid_repo_names.include?(light_repo.name.downcase)
      }
      [valid_repos, error_repo_names]
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
      "根据配置表(从远端或本地)同步仓库到工作区，包括被锁定仓库，已经在工作的不作处理（默认不执行pull）。"
    end

    def self.usage
      "mgit sync [-a|-n|-c] [<repo>...] [-p] [-o] [-h]"
    end

  end

end
