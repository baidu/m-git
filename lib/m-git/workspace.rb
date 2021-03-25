
require 'm-git/workspace/workspace_helper'
require 'm-git/workspace/path_helper'

module MGit
  class Workspace
    # @!attribute 仓库过滤器，过滤执行的仓库
    #
    RepoFilterConfig = Struct.new(:auto_exec, :include_lock, :select_repos, :exclude_repos)

    class << self

      include WorkspaceHelper
      include PathHelper

      attr_reader :root

      attr_reader :config

      def filter_config
        @filter_config ||= RepoFilterConfig.new
      end

      # 配置mgit根目录
      def setup_multi_repo_root(initial_root=nil)
        if initial_root
          @root = initial_root
          return
        end
        @root = multi_repo_root_path
        if @root.nil?
          Foundation.help!('该目录不是多仓库目录!!!')
        end
      end

      # 解析配置文件（完成后可使用@config获取配置对象）
      #
      # @param strict_mode [Boolean] default: true 严格模式下，出错直接终止，非严格模式下，出错则抛出异常
      #
      def setup_config(strict_mode:true)
        # 记录旧config哈希
        hash_sha1 = config.hash_sha1 if !config.nil?

        # 调用manifest_hook
        HooksManager.execute_manifest_hook(strict_mode:strict_mode)

        # 解析config
        @config = Manifest.parse(source_config_dir)

        # 是否更新了配置表
        did_update = hash_sha1.nil? || hash_sha1 != config.hash_sha1

        # --- 同步工作区 ---
        begin
          # 从配置中读取
          should_sync_workspace = MGitConfig.query_with_key(root, :syncworkspace)
          if should_sync_workspace
            # 同步工作区仓库（缓存或弹出）
            Utils.sync_workspace(root, config)
          else
            # 若禁止同步的话，则将缓存弹出（若有的话）
            config.light_repos.each { |light_repo|
              if !Dir.exist?(light_repo.abs_dest(root))
                pop(root, light_repo)
              end
            }
          end
        rescue Error => _
          Output.puts_fail_message("MGit配置读取失败，跳过工作区同步！")
        end

        # ------------------

        # --- 同步.git实体 ---
        begin
          # 从配置中读取
          manage_git = MGitConfig.query_with_key(root, :managegit)
          if !manage_git
            Utils.pop_git_entity(root, config)
          else
            # 当前逻辑是如果配置了托管.git的话，此时不压入.git，而是只把新下载仓库的.git压入
            # 后续如果有需要的话可以打开下面这个注释，这样在每次执行mgit指令时都会根据配置压入.git，起到同步的作用
            # Workspace.push_git_entity(@root, @config)
          end
        rescue Error => _
          Output.puts_fail_message("MGit配置读取失败，跳过.git同步！")
        end
        # ------------------
        did_update
      end

      # 更新配置解析结果，并同步缺失仓库
      def update_config(strict_mode:true)
        Output.puts_processing_message("检查多仓库配置信息...")
        if setup_config(strict_mode:strict_mode)
          Output.puts_success_message("配置信息已更新！\n")
        else
          # 配置表未更新，直接返回
          Output.puts_success_message("配置信息已为最新！\n")
          return
        end

        origin_all_repo_names = all_repos.map { |e| e.name }
        @all_repos, @exec_light_repos = nil, nil
        missing_repos = []
        missing_light_repos = setup_all_repos(strict_mode:false)
        if missing_light_repos.length > 0

          Utils.show_clone_info(root, missing_light_repos)
          mutex = Mutex.new
          error_repos = {}
          task_count = 0
          Output.update_progress(missing_light_repos.length, task_count)
          concurrent_enumerate(missing_light_repos) { |light_repo|
            error_message, _ = Repo::SyncHelper.sync_new_repo(light_repo, root)
            mutex.lock
            if error_message.nil?
              missing_repos.push(Repo.generate_strictly(root, light_repo))
            else
              error_repos[light_repo.name] = error_message
            end
            task_count += 1
            Output.update_progress(missing_light_repos.length, task_count)
            mutex.unlock
          }
          if error_repos.length > 0
            show_error(error_repos, action:'下载操作')
            #（注意，如果不希望被下载仓库的.git实体被mgit管理，请执行\"mgit sync -n -o\"，该方式将不会把.git实体放置到.mgit/souce-git中，更适合开发中途接入mgit的用户）
            Foundation.help!("请检查原因并执行\"mgit sync -n\"重新下载。")
          else
            Output.puts_success_message("下载成功！\n")
          end
        end

        # 加入将当前分支上本地已有的新仓库
        current_branch_exist_new_repos = all_repos.select { |repo| !origin_all_repo_names.include?(repo.name) }
        missing_repos += current_branch_exist_new_repos

        # 新仓库当前分支可能并不是所需分支，可以再进一步操作
        yield(missing_repos) if block_given? && missing_repos.length > 0
      end

      # 配置实体仓库对象（完成后可通过all_repos方法或@all_repos属性获取所有可执行仓库对象）
      #
      # @param strict_mode [Boolean] default: true 严格模式下，出错直接终止，非严格模式下，出错则抛出异常
      #
      def setup_all_repos(strict_mode: true)
        repos = []
        locked_repos = []
        missing_light_repos = []

        need_sync_repos = []
        exec_light_repos.each do |light_repo|
          need_sync_repos << light_repo unless Repo.check_git_dest(root, light_repo)
        end

        if need_sync_repos.length > 0
          sync_new_repos(need_sync_repos)
        end

        exec_light_repos.each { |light_repo|

          if strict_mode
            repo = Repo.generate_strictly(root, light_repo)
          else
            repo, _ = Repo.generate_softly(root, light_repo)
          end

          if !repo.nil?
            # 同步被锁仓库，不加入到本次执行中
            if repo.config.lock
              locked_repos.push(repo)
            else
              repos.push(repo)
            end
          else
            missing_light_repos.push(light_repo)
          end
        }

        # 同步锁定仓库
        sync_locked_repos(locked_repos)

        @locked_repos = locked_repos
        @all_repos = repos
        @all_repos += locked_repos if filter_config.include_lock

        missing_light_repos
      end

      # 获取所有仓库
      def all_repos(except_config:false)
        setup_all_repos if @all_repos.nil?

        if except_config
          @all_repos.select { |e| !e.config.is_config_repo }
        else
          @all_repos
        end
      end

      def locked_repos
        setup_all_repos if @locked_repos.nil?
        @locked_repos
      end

      # 提供一组light repo，更新repo对象
      def update_all_repos(update_repos_names)
        if update_repos_names.is_a?(Array)
          update_light_repos = config.repo_list(selection:update_repos_names)
          @exec_light_repos = update_light_repos
          @all_repos = nil
          setup_all_repos
        end
      end

      # 抽取本次需要执行指令的仓库对应的LightRepo
      #
      # @return [Array<LightRepo>] 本次需要执行指令的LightRepo数组
      #
      def exec_light_repos
        if @exec_light_repos.nil?
          mrepo_opt = filter_config.select_repos
          exclude_mrepo_opt = filter_config.exclude_repos

          selected_repos = mrepo_opt.value if !mrepo_opt.nil?
          excluded_repos = exclude_mrepo_opt.value if !exclude_mrepo_opt.nil?

          # 校验参数是否正确
          check_repo_names = []
          check_repo_names.concat(selected_repos) if selected_repos
          check_repo_names.concat(excluded_repos) if excluded_repos
          unless check_repo_names.empty?
            light_repo_names = config.light_repos.map(&:name)
            extra_names = check_repo_names - light_repo_names
            Foundation.help!("指定的仓库名称#{extra_names}不存在，请检查命令指定的参数") unless extra_names.empty?
          end

          @exec_light_repos = config.repo_list(selection:selected_repos, exclusion:excluded_repos)
        end
        @exec_light_repos
      end

      # -----------------------------------------------
      # 校验mgit根目录
      def multi_repo_root_path
        dir = Dir.pwd
        while File.dirname(dir) != dir do
          Dir.foreach(dir) do |filename|
            next unless File.directory?(File.join(dir, filename))
            return dir if filename == '.mgit'
          end
          dir = File.dirname(dir)
        end
        nil
      end

      # 生成配置仓库的Repo对象
      #
      # @return [Repo] 配置仓库的Repo对象
      #
      def generate_config_repo
        config_light_repo = exec_light_repos.find { |light_repo| light_repo.is_config_repo == true }
        if !config_light_repo.nil?
          repo, _ = Repo.generate_softly(root, config_light_repo)
          return repo
        else
          return nil
        end
      end


      def concurrent_enumerate_with_progress_bar(light_repos, message, &exec_handler)
        Output.puts_processing_block(light_repos.map { |e| e.name }, message)
        concurrent_enumerate_with_progress_bar_pure(light_repos, &exec_handler)
      end

      def concurrent_enumerate_with_progress_bar_pure(light_repos, &exec_handler)
        task_count = 0
        Output.update_progress(light_repos.length, task_count)
        concurrent_enumerate(light_repos) { |light_repo|
          exec_handler.call(light_repo) if exec_handler
          Lock.mutex_puts {
            task_count += 1
            Output.update_progress(light_repos.length, task_count)
          }
        }
      end

      def sync_new_repos(repos)
        return if repos.length == 0

        error_repos = {}

        Utils.show_clone_info(root, repos)
        concurrent_enumerate_with_progress_bar_pure(repos) { |light_repo|
          error_message, _ = Repo::SyncHelper.sync_new_repo(light_repo, root)
          if !error_message.nil?
            Lock.mutex_exec { error_repos[light_repo.name] = error_message }
          end
        }

        # 执行下载后hook
        repos_need_to_guide = []
        concurrent_enumerate(repos) { |light_repo|
          if error_repos[light_repo.name].nil? && # 下载未出错
              !light_repo.lock && # 不是锁定仓库
              !HooksManager.execute_post_download_hook(light_repo.name, light_repo.abs_dest(root)) # hook没有修改HEAD
            repos_need_to_guide.push(light_repo)
          end
        }

        # 引导分支切换
        if repos_need_to_guide.length > 0
          existing_repos = []
          missing_repos = []
          config.repo_list.each { |light_repo|
            repo, _ = Repo.generate_softly(root, light_repo)
            if !repo.nil?
              if repos_need_to_guide.include?(light_repo)
                missing_repos.push(repo)
              else
                existing_repos.push(repo)
              end
            end
          }

          repo_combo = missing_repos + existing_repos
          if has_diff_branch?(repo_combo)
            # 提示切换新下载仓库
            guide_to_checkout_branch(missing_repos, existing_repos)
            # 切换完成后如果所出分支不一致，给出提示
            Output.puts_remind_message("注意，当前所有仓库并不处于统一分支，可通过\"mgit branch --compact\"查看。") if has_diff_branch?(repo_combo)
          end
        end

        if error_repos.length > 0
          show_error(error_repos, action:'锁定')
        end
      end

      # 同步锁定仓库
      def sync_locked_repos(repos)
        return if repos.length == 0

        Output.puts_processing_message("正在锁定#{repos.length}个仓库...")
        mutex = Mutex.new
        error_repos = {}
        concurrent_enumerate(repos) { |repo|
          error_message = Repo::SyncHelper.sync_exist_repo(repo, repo.config)
          if !error_message.nil?
            mutex.lock
            error_repos[repo.name] = error_message
            mutex.unlock
          end
        }
        if error_repos.length > 0
          show_error(error_repos, action:'锁定')
        end
      end

      # 校验分支统一性
      def check_branch_consistency
        if has_diff_branch?(all_repos)
          if filter_config.auto_exec || Output.continue_with_user_remind?("当前所有仓库并不处于同一分支(可通过\"mgit branch --compact\"查看)，是否继续？")
            return
          else
            Output.puts_cancel_message
            exit
          end
        end
      end

      # 检查是否存在不一致的分支
      #
      # @return [Boolean] 是否存在不一致分支
      #
      def has_diff_branch?(repos)
        return false if repos.length == 0

        branch = nil
        repos.each { |repo|
          current_branch = repo.status_checker.current_branch(strict_mode:false)
          # current_branch为空值意味着HEAD游离
          if current_branch.nil? || (!branch.nil? && branch != current_branch)
            return true
          elsif branch.nil?
            branch = current_branch
          end
        }
        return false
      end

      # 引导切换新仓库的分支
      #
      # @param missing_repos [Array<Repo>] 缺失仓库
      #
      # @param exist_repos [Array<Repo>] 已有仓库
      #
      # @return [Array<Repo>] 切换成功的仓库
      #
      def guide_to_checkout_branch(new_repos, exist_repos, append_message:nil)
        return [] if new_repos.length == 0 || exist_repos.length == 0

        # 寻找最多仓库所在分支作为推荐
        branch_count = {}
        exist_repos.each { |repo|
          branch = repo.status_checker.current_branch(strict_mode:false, use_cache:true)
          if !branch.nil?
            branch_count[branch] = 0 if branch_count[branch].nil?
            branch_count[branch] += 1
          end
        }
        # 若已有仓库都游离，无法推荐切换，则直接返回
        return [] if branch_count.length == 0
        max_branch = branch_count.max_by { |k,v| v }.first

        branch_group = {}
        new_repos.each { |repo|
          branch = repo.status_checker.current_branch(strict_mode:false, use_cache:true)
          if branch.nil?
            branch = 'HEAD游离'
          elsif branch == max_branch
            next
          end
          branch_group[branch] = [] if branch_group[branch].nil?
          branch_group[branch].push(repo.name)
        }

        # 如果新仓库都在当前推荐分支则不操作
        if branch_group.length == 0
          return new_repos
          # 指定了auto则跳过提示，直接开始同步
        elsif branch_group.length > 0 && (filter_config.auto_exec || Output.continue_with_combined_interact_repos?(branch_group.to_a, "检测到已有的仓库大部分(或全部)处于分支：#{max_branch}\n    是否将以上仓库切换到该分支#{"(#{append_message})" if !append_message.nil?}？", title:'新仓库所在分支'))

          do_repos = []
          remind_repos = []

          new_repos.each { |repo|
            if repo.status_checker.local_branch_exist?(max_branch) || repo.status_checker.remote_branch_exist?(max_branch)
              do_repos.push(repo)
            else
              remind_repos.push(repo)
            end
          }

          Output.puts_fail_block(remind_repos.map { |e| e.name }, "以上仓库无对应分支，已跳过，请自行处理。") if remind_repos.length > 0

          if do_repos.length > 0
            Output.puts_processing_message("开始切换分支...")
            _, error_repos = execute_git_cmd_with_repos('', '', do_repos) { |repo|
              opts = "#{remind_repos.include?(repo) ? '-b ' : ''}#{max_branch}"
              ["checkout", opts]
            }

            if error_repos.length > 0
              return do_repos.select { |repo| !error_repos.keys.include?(repo.name)}
            else
              Output.puts_success_message("分支切换成功！\n")
              return do_repos
            end

          end
        end

        return []
      end

      # 并发遍历
      def concurrent_enumerate(array)
        begin
          max_concurrent_count = MGitConfig.query_with_key(root, :maxconcurrentcount)
        rescue Error => e
          Foundation.help!(e.msg)
        end

        array.peach(max_concurrent_count) { |item|
          yield(item) if block_given?
        }
      end

      # 带进度条串行执行
      def serial_enumerate_with_progress(array)
        task_count = 0
        Output.update_progress(array.length, task_count)
        array.each { |repo|
          yield(repo) if block_given?
          task_count += 1
          Output.update_progress(array.length, task_count)
        }
      end

      # git指令透传执行
      def execute_git_cmd_with_repos(cmd, git_opts, repos)
        mutex = Mutex.new
        success_repos = {}
        error_repos = {}
        task_count = 0
        Output.update_progress(repos.length, task_count)
        concurrent_enumerate(repos) { |repo|
          # 允许针对仓库对指令进行加工
          cmd, git_opts = yield(repo) if block_given?
          success, output = repo.execute_git_cmd(cmd, git_opts)

          mutex.lock
          if success
            success_repos[repo.name] = output
          else
            error_repos[repo.name] = output
          end
          task_count += 1
          Output.update_progress(repos.length, task_count)
          mutex.unlock
        }
        show_error(error_repos)
        return success_repos, error_repos
      end

      # shell指令透传执行(串行)
      def execute_common_cmd_with_repos(abs_cmd, repos)
        success_repos = {}
        error_repos = {}
        task_count = 0
        Output.update_progress(repos.length, task_count)
        repos.each { |repo|
          # 允许针对仓库对指令进行加工
          abs_cmd = yield(repo) if block_given?
          new_abs_cmd = "cd \"#{repo.path}\" && #{abs_cmd}"
          success, output = repo.execute(new_abs_cmd)
          if success
            success_repos[repo.name] = output
          else
            error_repos[repo.name] = output
          end
          task_count += 1
          Output.update_progress(repos.length, task_count)
        }
        show_error(error_repos)
        return success_repos, error_repos
      end

      # shell指令透传执行(并发)
      def execute_common_cmd_with_repos_concurrent(abs_cmd, repos)
        mutex = Mutex.new
        success_repos = {}
        error_repos = {}
        task_count = 0
        Output.update_progress(repos.length, task_count)
        concurrent_enumerate(repos) { |repo|
          # 允许针对仓库对指令进行加工
          abs_cmd = yield(repo) if block_given?
          new_abs_cmd = "cd \"#{repo.path}\" && #{abs_cmd}"
          success, output = repo.execute(new_abs_cmd)

          mutex.lock
          if success
            success_repos[repo.name] = output
          else
            error_repos[repo.name] = output
          end
          task_count += 1
          Output.update_progress(repos.length, task_count)
          mutex.unlock
        }
        show_error(error_repos)
        return success_repos, error_repos
      end

      # 显示错误信息
      def show_error(error_repos, action:nil)
        if error_repos.keys.length > 0
          # 压缩错误信息
          error_detail = {}
          error_repos.each { |repo_name, error|
            error = '指令执行失败，但无任何输出，请自行检查。' if error == ''
            error_detail[error] = [] if error_detail[error].nil?
            error_detail[error].push(repo_name)
          }

          # 显示错误
          error_detail.each { |error, repos|
            Output.puts_fail_block(repos, "以上仓库执行#{action}失败，原因：\n#{error}")
          }
        end
      end

      # 获取当前分支远程仓库信息
      def pre_fetch
        Output.puts_processing_message("获取远程仓库信息...")
        mutex = Mutex.new
        error_repos = {}
        task_count = 0
        Output.update_progress(all_repos.length, task_count)
        concurrent_enumerate(all_repos) { |repo|
          Timer.start(repo.name, use_lock:true)
          git_cmd = repo.git_cmd('fetch', '')
          Utils.execute_shell_cmd(git_cmd) { |stdout, stderr, status|
            error_msg = GitMessageParser.new(repo.config.url).parse_fetch_msg(stderr)

            mutex.lock
            if !status.success? || !error_msg.nil?
              error_repos[repo.name] = error_msg.nil? ? stderr : error_msg
            end
            task_count += 1
            Output.update_progress(all_repos.length, task_count)
            mutex.unlock
            Timer.stop(repo.name, use_lock:true)

            # 标记状态更新
            repo.status_checker.refresh
          }
        }
        if error_repos.length > 0
          show_error(error_repos, action:"远程查询")
        else
          Output.puts_success_message("获取成功！\n") if error_repos.length == 0
        end
      end

      # 检查是否是全部定义的子仓库
      #
      # @param subrepos [LightRepo] 仓库轻量对象集合
      #
      # @return [Boolean] 是否是所有子仓库
      #
      def is_all_exec_sub_repos?(subrepos)
        if subrepos.is_a?(Array)
          subrepo_names = subrepos.map { |e| e.name }
          return is_all_exec_sub_repos_by_name?(subrepo_names)
        end
      end

      # 检查是否是全部定义的子仓库
      #
      # @param subrepos [String] 仓库名字数组
      #
      # @return [Boolean] 是否是所有子仓库
      #
      def is_all_exec_sub_repos_by_name?(subrepo_names)
        if subrepo_names.is_a?(Array)
          all_subrepo_name = config.repo_list.select { |e| !e.lock && !e.is_config_repo }.map { |e| e.name }
          return subrepo_names == all_subrepo_name
        end
      end

    end
  end
end
