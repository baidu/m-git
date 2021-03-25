#coding=utf-8

module MGit
  class Workspace
    module WorkspaceHelper
      # 弹出托管的.git实体
      #
      # @param root [String] mgit工程根目录
      #
      # @param light_repo [Manifest::LightRepo] 操作仓库的配置repo
      #
      def pop_git_entity(root, light_repo)
        # 仓库工作区目录
        repo_dir = light_repo.abs_dest(root)

        # 仓库工作区.git软链接路径
        workspace_git_link_path = File.join(repo_dir, '.git')

        # 仓库.git实体托管路径
        git_entity_path = File.join(light_repo.git_store_dir(root), '.git')

        if Dir.exist?(git_entity_path) && Dir.exist?(workspace_git_link_path) && File.symlink?(workspace_git_link_path)
          # 仓库工作区.git软链接指向路径
          abs_link_point = File.join(repo_dir, File.readlink(workspace_git_link_path))

          # 若指向路径就是.git实体托管路径，则删除工作区软链接，并把.git弹出
          if Pathname.new(abs_link_point).realpath.to_s == git_entity_path
            FileUtils.rm_f(workspace_git_link_path)
            FileUtils.mv(git_entity_path, repo_dir)
          end
        end
      end

      # 压入（托管）.git实体
      #
      # @param root [String] mgit工程根目录
      #
      # @param light_repo [Manifest::LightRepo] 操作仓库的配置repo
      #
      def push_git_entity(root, light_repo)
        # 仓库工作区目录
        repo_dir = light_repo.abs_dest(root)
        git_store_dir = light_repo.git_store_dir(root)

        # 仓库工作区.git实体路径
        workspace_git_entity_path = File.join(repo_dir, '.git')

        # 仓库.git实体托管路径
        cache_git_entity_path = File.join(git_store_dir, '.git')

        # 工作区.git存在，且mgit没有已存在的托管的.git
        if Dir.exist?(workspace_git_entity_path) && !Dir.exist?(cache_git_entity_path)
          # 移动并链接
          Utils.link_git(repo_dir, git_store_dir)
        end
      end

      # 将缓存的仓库移动到工作区
      #
      # @param root [String] mgit工程根目录
      #
      # @param light_repo [Manifest::LightRepo] 操作仓库的配置repo
      #
      def pop(root, light_repo)
        cache_path = File.join(light_repo.cache_store_dir(root), light_repo.name)
        workspace_path = light_repo.abs_dest(root)
        workspace_dir = File.dirname(workspace_path)
        return if invalid_move?(cache_path, workspace_dir)

        if Dir.exist?(cache_path) && !Dir.exist?(workspace_path)

          # 工作区目录不存在则创建
          FileUtils.mkdir_p(workspace_dir) if !Dir.exist?(workspace_dir)

          begin
            # 【注意】 FileUtils.mv(a,b) 如果b路径的basename不存在，那么自动创建b并将【a文件夹内的所有文件】拷贝到b(b/<content of a>)，如果basename存在，那么直接把a文件夹整个移动到b下(b/a/<content of a>)。
            FileUtils.mv(cache_path, workspace_dir)
          rescue => _
          end
        end
      end

      # 将工作区的仓库缓存起来
      #
      # @param root [String] mgit工程根目录
      #
      # @param light_repo [Manifest::LightRepo] 操作仓库的配置repo
      #
      def push(root, light_repo)
        cache_dir = light_repo.cache_store_dir(root)
        workspace_path = light_repo.abs_dest(root)
        return if invalid_move?(workspace_path, cache_dir)

        cache_path = File.join(cache_dir, light_repo.name)
        if Dir.exist?(workspace_path)
          # 缓存存在则删除缓存
          FileUtils.rm_rf(cache_path) if Dir.exist?(cache_path)

          # 缓存目录不存在则创建
          FileUtils.mkdir_p(cache_dir) if !Dir.exist?(cache_dir)

          begin
            FileUtils.mv(workspace_path, cache_dir)
          rescue => _
          end
        end
      end

      # 将工作区的仓库a替换为b
      #
      # @param root [String] mgit工程根目录
      #
      # @param light_repo_a [Manifest::LightRepo] 缓存仓库的配置repo
      #
      # @param light_repo_b [Manifest::LightRepo] 弹出仓库的配置repo
      #
      def replace(root, light_repo_a, light_repo_b)
        push(root, light_repo_a)
        pop(root, light_repo_b)
      end

      # 根据工作区仓库url和配置url来替换仓库
      #
      # @param root [String] mgit工程根目录
      #
      # @param light_repo [Manifest::LightRepo] 操作仓库的配置repo
      #
      def sync_workspace(root, light_repo)
        name = light_repo.name
        path = light_repo.abs_dest(root)

        # 若工作区存在该仓库，且url与配置不匹配，则压入缓存，此时如果配置的url有对应缓存，则将其弹出
        if Repo.is_git_repo?(path)
          repo = Repo.new(name, path)
          url = repo.status_checker.default_url
          if !Utils.url_consist?(url, light_repo.url)
            repo_config = Manifest::LightRepoGenerator.simple_init(name, path, url)
            replace(root, repo_config, light_repo)
          end

          # 若工作区不存在该仓库，则弹出配置url对应缓存（如有缓存的话）
        else
          pop(root, light_repo)
        end
      end

      # 判断是否可以移动目录，若目标目录包含源目录，则无法移动
      #
      # @param from_path [String] 源目录
      #
      # @param to_path [String] 目标目录
      #
      def invalid_move?(from_path, to_path)
        return Pathname(to_path).cleanpath.to_s.include?(Pathname(from_path).cleanpath.to_s)
      end

    end
  end
end
