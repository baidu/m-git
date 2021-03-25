
module MGit
  module HooksManager

# --- 执行hook ---

    class << self
      # 获取配置表前执行的hook
      #
      # @param strict_mode [Boolean] default: true 严格模式下出错直接终止，非严格模式下出错抛出异常
      #
      # @return [Type] description_of_returned_object
      #
      def execute_manifest_hook(strict_mode:true)
        __execute_hook_file(Constants::HOOK_NAME[:manifest_hook], 'MGitTemplate::ManifestHook') do |cls|
          begin
            cls.run
          rescue Error => e
            if strict_mode
              Foundation.help!("配置表生成失败：#{e.msg}") if e.type == MGIT_ERROR_TYPE[:config_generate_error]
            else
              raise e
            end
          end
        end
      end

      # mgit执行前的hook
      def execute_mgit_pre_hook(cmd, pure_opts)
        __execute_hook_file(Constants::HOOK_NAME[:pre_hook], 'MGitTemplate::PreHook') do |cls|
          cls.run(cmd, pure_opts, Workspace.root)
        end
      end

      # mgit执行后的hook
      def execute_mgit_post_hook(cmd, pure_opts, light_repos)
        __execute_hook_file(Constants::HOOK_NAME[:post_hook], 'MGitTemplate::PostHook') do |cls|
          cls.run(cmd, pure_opts, Workspace.root, light_repos)
        end
      end

      # mgit执行前的hook（用户级，此时已经完成状态检查，可以在内部获取到仓库配置对象）
      # 可以按需插入到不同指令的执行前时机下调用，然后在方法中通过'cmd'参数判断当前执行到是哪个指令
      # 目前仅插入到commit指令，后续可按需插入
      def execute_mgit_pre_exec_hook(cmd, pure_opts, light_repos)
        __execute_hook_file(Constants::HOOK_NAME[:pre_exec_hook], 'MGitTemplate::PreExecHook') do |cls|
          cls.run(cmd, pure_opts, Workspace.root, light_repos)
        end
      end

      # 功能类似'execute_mgit_pre_exec_hook'，但仅仅是push指令专用（内部不用判断'cmd'，cmd一定是push，可替换为'execute_mgit_pre_exec_hook'）
      def execute_mgit_pre_push_hook(cmd, pure_opts, light_repos)
        __execute_hook_file(Constants::HOOK_NAME[:pre_push_hook], 'MGitTemplate::PrePushHook') do |cls|
          cls.run(cmd, pure_opts, Workspace.root, light_repos)
        end
      end

      # 执行下载后的hook
      #
      # @param repo_name [String] 仓库ming
      #
      # @param repo_path [String] 仓库本地路径
      #
      # @param root [String] .mgit所在目录
      #
      # @param error [String] 错误信息，nil表示成功
      #
      # @return [Boolean] hook是否操作过仓库分支
      #
      def execute_post_download_hook(repo_name, repo_path)
        changed = __execute_hook_file(Constants::HOOK_NAME[:post_download_hook], 'MGitTemplate::PostDownloadHook') do |cls|
          cls.run(repo_name, repo_path)
        end
        changed == true
      end

      # 执行hook文件
      #
      # @param file_name [String] hook文件名
      #
      # @param hook_class [String] hook Class name
      #
      # block
      def __execute_hook_file(file_name, hook_class)
        file_path = File.join(Workspace.hooks_dir, file_name)
        if File.exists?(file_path)
          require file_path
        end
        if Object.const_defined?(hook_class) && hook = Object.const_get(hook_class)
          return yield(hook) if block_given?
        end
      end
    end

  end
end
