#coding=utf-8

require 'm-git/open_api/script_download_info'

module MGit

  # --- Ruby环境调用 ---
  class OpenApi
    class << self

      # 根据配置表下载仓库，并同步工作区
      #
      # @param config_content [String/Hash] 配置表json字符串或字典(key值需为String)，不可为nil。
      #
      # @param download_root [String] 仓库下载的根目录，不可为nil。
      #
      # Block: (OpenApi::ScriptDownloadInfo) 下载结果对象
      #
      # ========= 用法 ===========
      ### info对象：[OpenApi::ScriptDownloadInfo]
      # MGit::OpenApi.sync_repos(json,root) { |info|
      #   puts "name:#{info.repo_name} \n path:#{info.repo_path}\n result:#{info.result}\n error:#{info.output}\n progress:#{info.progress}"
      #   if info.result == OpenApi::DOWNLOAD_RESULT::EXIST
      #   elsif info.result == OpenApi::DOWNLOAD_RESULT::SUCCESS
      #   elsif info.result == OpenApi::DOWNLOAD_RESULT::FAIL
      #   end
      # }
      def sync_repos(config_content, download_root)
        # 空值校验
        error = self.validate_argv(__method__, {"config_content" => config_content, "download_root" => config_content})
        yield(ScriptDownloadInfo.new(nil, nil, DownloadResult::FAIL, error, 0)) if block_given? && !error.nil?

        begin
          config = Manifest.simple_parse(config_content, strict_mode:false)
        rescue Error => e
          yield(ScriptDownloadInfo.new(nil, nil, DownloadResult::FAIL, e.msg, 0)) if block_given?
          return
        end

        # 同步工作区仓库（压入或弹出），此时配置表缓存未覆盖，同步操作若取消无需恢复缓存。
        Utils.sync_workspace(download_root, config, recover_cache_if_cancelled:false)

        # 更新配置缓存
        config.update_cache_with_content(download_root, config.config)

        # 下载
        self.download(config, download_root, sync_exist:true) { |download_info|
          yield(download_info) if block_given?
        }

      end

      # 根据配置表下载仓库
      #
      # @param config_content [String/Hash] 配置表json字符串或字典(key值需为String)，不可为nil。
      #
      # @param download_root [String] 仓库下载的根目录，不可为nil。
      #
      # @param manage_git [Boolean] 新下载的仓库是否托管.git，若为false，则在工作区保留新克隆仓库的.git，否则将.git托管到.mgit/sourct-git中，并在工作区创建其软链接
      #
      # Block: (OpenApi::ScriptDownloadInfo) 下载结果对象
      #
      # ========= 用法 ===========
      ### info对象：[OpenApi::ScriptDownloadInfo]
      # MGit::OpenApi.download_repos(json,root) { |info|
      #   puts "name:#{info.repo_name} \n path:#{info.repo_path}\n result:#{info.result}\n error:#{info.output}\n progress:#{info.progress}"
      #   if info.result == OpenApi::DOWNLOAD_RESULT::EXIST
      #   elsif info.result == OpenApi::DOWNLOAD_RESULT::SUCCESS
      #   elsif info.result == OpenApi::DOWNLOAD_RESULT::FAIL
      #   end
      # }
      def download_repos(config_content, download_root, manage_git:true)

        # 空值校验
        error = self.validate_argv(__method__, {"config_content" => config_content, "download_root" => config_content})
        yield(ScriptDownloadInfo.new(nil, nil, DownloadResult::FAIL, error, 0)) if block_given? && !error.nil?

        begin
          config = Manifest.simple_parse(config_content, strict_mode:false)
        rescue Error => e
          yield(ScriptDownloadInfo.new(nil, nil, DownloadResult::FAIL, e.msg, 0)) if block_given?
          return
        end

        self.download(config, download_root, manage_git:manage_git) { |download_info|
          yield(download_info) if block_given?
        }

      end

      # 将仓库切到特定的分支或commit
      #
      # @param repo_name [String] 仓库名，不可为nil。
      #
      # @param repo_path [String] 仓库本地地址，不可为nil。
      #
      # @param create_branch [String] 是否创建新分支。
      #
      # @param branch [String] 需要切换的分支，可为nil。。
      #                         如果非nil，若仓库有该分支则直接切换，没有则在指定commit上创建。
      #                         如果为nil，则直接切换到指定commit。
      #
      # @param commit_id [String] 需要切换的commit id，不可为nil。
      #
      # @param allow_fetch [String] 指定在本地无指定分支或commit时是否fetch后重试。
      #
      # @return [(String, Boolean)] (error, did_create_new_branch)
      #                              - error: 错误信息，若无错误，返回nile
      #                              - did_create_new_branch: 本次checkout是否创建新分支
      # ========= 用法 ===========
      ### 自信切commit
      # MGit::OpenApi.checkout(name, abs_path, base_commit:'4922620')
      #
      ### 自信切分支，分支确定存在
      # MGit::OpenApi.checkout(name, abs_path, branch:'master')
      #
      ### 尝试切分支，没有就创建
      # MGit::OpenApi.checkout(name, abs_path, create_branch:true, branch:'master', base_commit:'4922620')
      def checkout(repo_name, repo_path, create_branch:false, branch:nil, base_commit:nil, allow_fetch:false)

        # 空值校验
        error = self.validate_argv(__method__, {"repo_name" => repo_name, "repo_path" => repo_path})
        return error, false if !error.nil?
        return 'branch和base_commit必须传入一个值！', false if branch.nil? && base_commit.nil?

        # 生成仓库对象
        if Repo.is_git_repo?(repo_path)
          repo = Repo.new(repo_name, repo_path)
        else
          return "路径位置\"#{repo_path}\"不是git仓库！", false
        end

        error = nil
        did_create_new_branch = false

        # 如果指定可fetch，那么在本地缺失信息时执行fetch
        if allow_fetch

          # 查询分支和commit
          should_fetch = !branch.nil? && !repo.status_checker.local_branch_exist?(branch) ||
                          !base_commit.nil? && !repo.status_checker.commit_exist?(base_commit)

          error = fetch(repo.name, repo.path) if should_fetch

          return error, did_create_new_branch if !error.nil?
        end

        if !branch.nil?

          # 已在指定分支则不操作
          if repo.status_checker.current_branch(strict_mode:false) != branch

            # 有本地改动禁止新建/切换分支
            if repo.status_checker.status == Repo::Status::GIT_REPO_STATUS[:dirty]
              error = "仓库#{repo_name}有改动，无法切换/创建分支！"

            # 有本地或对应远程分支，直接切换
            elsif repo.status_checker.local_branch_exist?(branch) || repo.status_checker.remote_branch_exist?(branch)
              success, output = repo.execute_git_cmd('checkout', branch)
              error = output if !success

            # 无分支，在指定commit上创建
            elsif create_branch

              if !base_commit.nil?
                if repo.status_checker.commit_exist?(base_commit)
                  success, output = repo.execute_git_cmd('checkout', "-b #{branch} #{base_commit}")
                  if !success
                    error = output
                  else
                    did_create_new_branch = true
                  end
                else
                  error = "仓库#{repo_name}创建新分支时，未找到指定基点commit！"
                end
              else
                error = "仓库#{repo_name}创建新分支时，没有指定基点commit！"
              end

            else
              error = "仓库#{repo_name}无分支#{branch}，且未指定创建！"
            end

          end

        elsif !base_commit.nil?

          # 已在指定commit则不操作
          if !repo.status_checker.current_branch(strict_mode:false).nil? ||
            repo.status_checker.current_head(strict_mode:false) != base_commit


            # 有本地改动禁止新建/切换分支
            if repo.status_checker.status == Repo::Status::GIT_REPO_STATUS[:dirty]
              error = "仓库#{repo_name}有改动，无法切换HEAD！"

            # 未指定branch，直接切到指定commit
            elsif repo.status_checker.commit_exist?(base_commit)
              success, output = repo.execute_git_cmd('checkout', base_commit)
              error = output if !success

            # 指定commit不存在报错
            else
              error = "仓库#{repo_name}切换操作失败，指定commit不存在！"
            end

          end

        end

        return error, did_create_new_branch
      end

      # 执行fetch操作
      #
      # @param repo_name [Stirng] 仓库名
      #
      # @param repo_path [String] 仓库路径
      #
      # @return [String] 错误信息，如果执行成功返回nil
      #
      def fetch(repo_name, repo_path)
        # 空值校验
        error = self.validate_argv(__method__, {"repo_name" => repo_name, "repo_path" => repo_path})
        return error if !error.nil?

        if Dir.exist?(repo_path) && Repo.is_git_repo?(repo_path)
          repo = Repo.new(repo_name, repo_path)
          success, output = repo.execute_git_cmd('fetch', '')
          return output if !success
        else
          return '指定路径不存在或不是git仓库！'
        end
      end

      # 执行pull操作
      #
      # @param repo_name [Stirng] 仓库名
      #
      # @param repo_path [String] 仓库路径
      #
      # @return [String] 错误信息，如果执行成功返回nil
      #
      def pull(repo_name, repo_path)
        # 空值校验
        error = self.validate_argv(__method__, {"repo_name" => repo_name, "repo_path" => repo_path})
        return error if !error.nil?

        if Dir.exist?(repo_path) && Repo.is_git_repo?(repo_path)
          repo = Repo.new(repo_name, repo_path)
          success, output = repo.execute_git_cmd('pull', '')
          return output if !success
        else
          return '指定路径不存在或不是git仓库！'
        end
      end

      # 检查给定仓库是否工作区脏，工作区的.git是否是软链接
      #
      # @param path_dict [Hash] 待校验的冗余仓库地址：{ "name": "abs_path" }
      #
      # @return [Hash] 冗余仓库状态信息：{ "name": { "clean": true, "git_linked": true , "error": "error_msg"} }
      #                  - "clean": 为true，表示工作区干净，否则脏。
      #                  - "git_linked": 为true，表示.git实体放在.mgit/source-git下，工作区.git仅为软链接，否则为实体。
      #                  - "error": 如果校验成功则无该字段，否则校验失败，值为错误信息。注意，若出错则无"clean"和"git_linked"字段。
      #
      def check_extra_repos(path_dict)

        # 空值校验
        error = self.validate_argv(__method__, {"path_dict" => path_dict})
        return {} if !error.nil?

        output = {}
        path_dict.each { |name, path|
          output[name] = {}
          # 生成仓库对象
          if Repo.is_git_repo?(path)
            repo = Repo.new(name, path)
            output[name]['clean'] = repo.status_checker.status == Repo::Status::GIT_REPO_STATUS[:clean]
            output[name]['git_linked'] = File.symlink?(File.join(path, '.git'))
          else
            output[name]['error'] = "路径位置\"#{repo_path}\"不是git仓库！"
          end
        }
        return output
      end

      # 并发遍历
      #
      # @param array [<Object>] 遍历数组
      #
      # @param max_concurrent_count [Integer] 最大并发数
      #
      # ========= 用法 ===========
      # concurrent_enumerate([item1, item2...]) { |item|
      #  do something with item...
      # }
      def concurrent_enumerate(array, max_concurrent_count:5)
        if array.is_a?(Array) && array.length > 0
          array.peach(max_concurrent_count) { |item|
            yield(item) if block_given?
          }
        end
      end

      # 在不拉仓库的情况下，批量查询当前用户是否有权限拉取代码
      #
      # @param root [String] 工程根目录
      #
      # @param url_list [Array<String>] 一组远程仓库url
      #
      # ========= 用法 ===========
      # url_list = [
      #   'https://github.com/baidu/baiduapp-platform/a',
      #   'https://github.com/baidu/baiduapp-platform/b'
      # ]
      # MGit::OpenApi.check_permission_batch(arr) { |url, has_permission, progress|
      #   do something...
      # }
      def check_permission_batch(root, url_list)
        mutex = Mutex.new
        task_count = 0
        total_task = url_list.length
        concurrent_enumerate(url_list) { |url|
          has_permission = self.check_permission(url, root:root)
          mutex.lock
          task_count += 1
          progress = Float(task_count) / total_task
          yield(url, has_permission, progress) if block_given?
          mutex.unlock
        }
      end

      # 在不拉仓库的情况下，查询当前用户是否有权限拉取代码
      #
      # @param root [String] 工程根目录
      #
      # @param url [String] 远程仓库url
      #
      # @return [Boolean] 是否有权限
      #
      # ========= 用法 ===========
      # url = 'https://github.com/baidu/baiduapp-platform/a'
      # result = MGit::OpenApi.check_permission(url)
      def check_permission(url, root:nil)
        if !root.nil?
          git_store = Utils.generate_git_store(root, url)
          if !git_store.nil? && Dir.exist?(git_store)
            return true
          end
        end

        return Utils.has_permission_of_remote?(url)
      end

      # ----- Util -----
      # 校验参数合法性
      #
      # @param method_name [String] 方法名
      #
      # @param args [Hash] 参数数组
      #
      # @return [String] 错误信息，正常返回nil
      #
      def validate_argv(method_name, args)
        args.each { |k,v|
          if v.nil?
            return "MGit API调用错误: MGit::OpenApi.#{method_name}()的#{k}参数不能为空！"
          end
        }
        return nil
      end

      # 根据配置对象下载仓库
      #
      # @param config_content [String/Hash] 配置表json字符串或字典(key值需为String)，不可为nil。
      #
      # @param download_root [String] 仓库下载的根目录，不可为nil。
      #
      # @param manage_git [Boolean] 新下载的仓库是否托管.git，若为false，则在工作区保留新克隆仓库的.git，否则将.git托管到.mgit/sourct-git中，并在工作区创建其软链接
      #
      # ========= 用法 ===========
      # self.download(config, download_root) { |download_info|
      #   do something with download_info....
      # }
      def download(config, download_root, manage_git:true, sync_exist: false)
        task_count = 0
        total_task = config.light_repos.length
        mutex = Mutex.new
        concurrent_enumerate(config.light_repos) { |light_repo|
          name = light_repo.name
          path = light_repo.abs_dest(download_root)
          result = nil
          output = nil
          progress = 0

          if Dir.exist?(path) && Repo.is_git_repo?(path)
            if sync_exist
              repo, error = Repo.generate_softly(download_root, light_repo)
              error = Repo::SyncHelper.sync_exist_repo(repo, repo.config) if !repo.nil?
            end
            result = DownloadResult::EXIST
          elsif Utils.has_permission_of_remote?(light_repo.url)
            error, repo = Repo::SyncHelper.sync_new_repo(light_repo, download_root, link_git:manage_git)
            if !error.nil?
              result = DownloadResult::FAIL
              output = error
            else
              result = DownloadResult::SUCCESS
            end
          else
            result = DownloadResult::FAIL
            output = "当前用户没有该仓库的克隆权限：#{light_repo.name}(#{light_repo.url})！"
          end

          mutex.lock
          task_count += 1
          progress = Float(task_count) / total_task
          yield(ScriptDownloadInfo.new(name, path, result, output, progress)) if block_given?
          mutex.unlock
        }
      end
    end

  end

end
