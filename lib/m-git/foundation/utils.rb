#coding=utf-8

module MGit
  module Utils

    class << self
      def logical_cpu_num
        if @logical_cpu_num.nil?
          begin
            num = `sysctl -n hw.logicalcpu`
            num = `cat /proc/cpuinfo | grep "processor" | wc -l` unless $?.success?
            @logical_cpu_num = num
          rescue Exception => _
            @logical_cpu_num = "5"
          end
        end
        @logical_cpu_num.to_i
      end

      # ----- Shell指令相关 -----

      # 执行shell指令
      def execute_shell_cmd(cmd)
        begin
          (stdout, stderr, status) = Open3.capture3(cmd)
        rescue => e
          puts "\n"
          Foundation.help!("指令 \"#{cmd}\" 执行异常：#{e.message}")
        end
        yield(stdout, stderr, status) if block_given?
        self
      end

      # ----- 目录相关 -----

      # 改变当前路径
      def change_dir(dir)
        return if dir == Dir.pwd
        begin
          Dir.chdir(dir)
        rescue => e
          raise "目录切换失败：#{e.message}"
        end
      end

      # 在某路径下执行代码
      def execute_under_dir(dir)
        origin_dir = Dir.pwd
        change_dir(dir)
        yield() if block_given?
        change_dir(origin_dir)
      end

      # 计算相对目录
      #
      # @param dir_a [String] 目录A，如‘/a/b/A’
      #
      # @param dir_b [String] 目录B，如‘/a/c/B’
      #
      # @return [String] A目录下文件相对B目录的路径，如‘../../c/B’
      #
      def relative_dir(dir_a, dir_b, realpath: true)
        if realpath
          (Pathname.new(dir_a).realpath.relative_path_from(Pathname.new(dir_b).realpath)).to_s
        else
          (Pathname.new(dir_a).relative_path_from(Pathname.new(dir_b))).to_s
        end
      end

      # 扩展成完整路径
      #
      # @param path [String] 路径名
      #
      # @param base [Type] default: nil 基准路径
      #
      # @return [String] 扩展后的完整路径
      #
      def expand_path(path, base:nil)
        pn = Pathname.new(path)
        if pn.relative?
          base = Dir.pwd if base.nil?
          File.expand_path(File.join(base, path))
        else
          path
        end
      end

      # 初始化缓存目录
      #
      # @return [String] 目录地址
      #
      def generate_init_cache_path(root)
        temp_dir = ".#{Constants::INIT_CACHE_DIR_NAME}__#{Process.pid}__#{Time.new.to_i.to_s}"
        File.join(root,temp_dir)
      end

      # 创建软连接
      #
      # @param target_path [String] 目标文件（文件夹）的绝对路径
      #
      # @param link_path [String] 软连接所在绝对路径
      #
      def link(target_path, link_path)
        target_relative_path = File.join(relative_dir(File.dirname(target_path), File.dirname(link_path)), File.basename(target_path))
        FileUtils.symlink(target_relative_path, link_path, force:true)
      end

      # 显示下载仓库信息
      #
      # @param missing_light_repos [Array<LightRepo>] 缺失仓库配置对象
      #
      def show_clone_info(root, missing_light_repos)
        notice_repo = []
        clone_from_local = []
        clone_from_remote = []
        missing_light_repos.each { |light_repo|
          if Dir.exist?(File.join(light_repo.git_store_dir(root), '.git'))
            clone_from_local += [light_repo.name]
          else
            clone_from_remote += [light_repo.name]
          end
        }

        notice_repo.push(['从本地导出', clone_from_local]) if clone_from_local.length > 0
        notice_repo.push(['从远程下载', clone_from_remote]) if clone_from_remote.length > 0

        puts Output.generate_table_combination(notice_repo, separator: "|")
        Output.puts_processing_message('以上仓库本地缺失，处理中...')
      end

      # ----- Git相关 -----

      # 在不拉取仓库的情况下，查询远程仓库是否存在某分支
      #
      # @return [Bool] 是否存在分支
      #
      def branch_exist_on_remote?(branch, git_url)
        return false if branch.nil? || git_url.nil?
        cmd = "git ls-remote --heads #{git_url} | grep \"#{branch}\""
        execute_shell_cmd(cmd) { |stdout, stderr, status|
          return status.success?
        }
      end

      # 在不拉仓库的情况下，查询当前用户是否有权限拉取代码
      #
      # @return [Bool] 是否有权限
      #
      def has_permission_of_remote?(git_url)
        return false if git_url.nil?
        cmd = "git ls-remote --heads #{git_url}"
        execute_shell_cmd(cmd) { |stdout, stderr, status|
          return status.success?
        }
      end

      # 链接.git仓库实体
      # 1、如果git实体存在，则删除，以当前仓库的.git为主
      # 2、移动仓库的.git到git实体
      # 3、软链仓库的.git为git实体
      #
      # @param source_dir [String] 源码路径
      #
      # @param source_git_dir [String] 存放git实体的路径
      #
      #
      #
      def link_git(source_dir, source_git_dir)

        # 工作区.git
        origin_git = File.join(source_dir, '.git')

        # 本地缓存的.git
        target_git = File.join(source_git_dir, '.git')

        FileUtils.remove_dir(target_git, true) if File.exist?(target_git)
        FileUtils.mkdir_p(source_git_dir) unless File.exist?(source_git_dir)

        FileUtils.mv(origin_git, source_git_dir)

        # 创建.git软链接
        link(target_git, origin_git)
      end

      # 根据url生成git实体存放路径
      #
      # @param url [String] 仓库url
      #
      # @return [String] .git实体存放地址，生成错误返回nil
      #
      def generate_git_store(root, url)
        return if url.nil?
        git_dir = File.join(root, Constants::PROJECT_DIR[:source_git])
        begin
          url_obj = URI(url)
          # 去除shceme
          url_path = File.join("#{url_obj.host}#{url_obj.port.nil? ? '' : ":#{url_obj.port}"}", url_obj.path)
          # 去除后缀名
          git_relative_dir = File.join(File.dirname(url_path), File.basename(url_path, File.extname(url_path)))

          File.join(git_dir, git_relative_dir)
        rescue
        end
      end

      # ----- 工作区同步相关 -----

      # 同步工作区(缓存或弹出)
      #
      # @param root [String] mgit管理工程根目录
      #
      # @param config [Manifest] 配置对象
      #
      # @param recover_cache_if_cancelled [Boolean] 如果回收过程中取消操作，是否恢复缓存
      #                                            （需要自行判断，如果方法调用前缓存已经覆盖，那么需要恢复以保障下次同步操作正常执行
      #                                              如果调用前缓存未被覆盖，则无需恢复，此时若强行恢复会干扰下次同步操作）
      #
      def sync_workspace(root, config, recover_cache_if_cancelled:true)

        # 若有缓存仓库，则移到工作区
        config.light_repos.each { |light_repo|
          #【注意】url不一致会认为是不同仓库，将缓存当前仓库，并弹出url对应缓存（若对应缓存则不弹出）
          Workspace.sync_workspace(root, light_repo)
        }

        # 更新冗余仓库数据
        if config.previous_extra_light_repos.nil? || config.previous_extra_light_repos.length == 0
          config.update_previous_extra_light_repos(root)
        end

        # 若工作区有多余仓库，则缓存
        if !config.previous_extra_light_repos.nil? && config.previous_extra_light_repos.length > 0

          dirty_repos = []
          do_repos = []
          config.previous_extra_light_repos.each { |light_repo|

            # 如果仓库是主仓库，则不操作
            next if light_repo.is_config_repo

            repo, error = Repo.generate_softly(root, light_repo)
            if error.nil?
              if repo.status_checker.status == Repo::Status::GIT_REPO_STATUS[:dirty]
                dirty_repos.push(repo)
              else
                do_repos.push(repo)
              end
            end
          }

          if dirty_repos.length > 0
            if Output.continue_with_interact_repos?(dirty_repos.map { |e| e.name }, '即将回收以上仓库，但存在本地改动，继续操作将丢失改动，是否取消？') ||
                Output.continue_with_user_remind?("即将丢失改动，是否取消？")
              # 用上次配置覆盖以恢复缓存，否则若此次缓存已被覆盖，取消后下次操作同步将失效
              config.update_cache_with_content(root, config.previous_config) if recover_cache_if_cancelled
              Foundation.help!('操作取消')
            end
          end

          current_time = Time.new.strftime("%Y%m%d%H%M%S")
          (dirty_repos + do_repos).each { |repo|
            if dirty_repos.include?(repo)
              repo.execute_git_cmd('add', '.')
              repo.execute_git_cmd('stash', "save -u #{current_time}_MGit回收仓库自动stash")
            end

            begin
              save_to_cache = MGitConfig.query_with_key(root, :savecache)
            rescue Error => _
              save_to_cache = false
            end

            # 如果仓库没有被管理，则不删除，直接缓存
            is_git_managed = Dir.exist?(File.join(repo.config.git_store_dir(root), '.git'))
            if save_to_cache || !is_git_managed
              Workspace.push(root, repo.config)
            else
              FileUtils.rm_rf(repo.path) if Dir.exist?(repo.path)
            end
          }

        end
      end

      def pop_git_entity(root, config)
        config.light_repos.each { |light_repo|
          # 将托管的.git弹出到工作区
          Workspace.pop_git_entity(root, light_repo)
        }
      end

      def push_git_entity(root, config)
        config.light_repos.each { |light_repo|
          # 将工作区的.git托管给mgit
          Workspace.push_git_entity(root, light_repo)
        }
      end

      # 判断url是否一致
      #
      # @param url_a [String] url
      #
      # @param url_b [String] url
      #
      # @return [Boolean] 是否一致
      #
      def url_consist?(url_a, url_b)
        # 删除冗余字符
        temp_a = normalize_url(url_a)
        temp_b = normalize_url(url_b)

        # 同时不为nil判断内容是否相等
        return temp_a == temp_b if !temp_a.nil? && !temp_b.nil?
        # reutrn | temp_a | temp_b
        # ----------------------
        #  true  |   nil  |   nil
        #  true  |   ''   |   nil
        #  true  |   nil  |   ''
        # ----------------------
        #  false |   nil  |   xxx
        #  false |   xxx  |   nil
        (temp_a.nil? && temp_b.nil?) || (!temp_a.nil? && temp_a.length == 0) || (!temp_b.nil? && temp_b.length == 0)
      end

      # 规范化url，删除冗余字符
      #
      # @param url [String] url字符串
      #
      # @return [String] 规范化后的url
      #
      def normalize_url(url)
        return if url.nil?
        refined_url = url.strip.sub(/(\/)+$/,'')
        return refined_url if refined_url.length == 0
        begin
          uri = URI(refined_url)
          return "#{uri.scheme}://#{uri.host}#{uri.port.nil? ? '' : ":#{uri.port}"}#{uri.path}"
        rescue  => _
        end
      end

      # 安全的路径拼接
      #
      # @param path_a [String] 路径a
      #
      # @param path_b [String] 路径b
      #
      # @return [String] 完整路径
      #
      def safe_join(path_a, path_b)
        if !path_a.nil? && path_a.length > 0 && !path_b.nil? && path_b.length > 0
          File.join(path_a, path_b)
        elsif !path_a.nil? && path_a.length > 0
          path_a
        elsif !path_b.nil? && path_b.length > 0
          path_b
        end
      end
    end
  end
end
