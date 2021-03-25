#coding=utf-8

require_relative 'light_repo_generator'

module MGit
  class Manifest
    # @!scope manifest.json 配置的reponsitories 对象
    # 该类用于配置解析后的初步处理，其字段与配置文件一致，但不保证与本地仓库状态一致。
    # 而Repo类则会校验本地仓库，其状态与本地仓库状态一致，主要用于执行多仓库操作。
    #
    LightRepo = Struct.new(
        # [String] 仓库名
        :name,

        # [String] 仓库相对mgit根目录的存放路径（完整路径如：<.mgit所在路径>/path/<repo_name>），或绝对路径（指定abs-dest）
        # 绝对路径
        :path,

        # [String] 仓库配置分支
        :branch,

        # [String] 仓库配置commit id
        :commit_id,

        # [String] 仓库配置tag
        :tag,

        # [String] 仓库的git地址
        :url,

        # [Boolean] 是否纳入mgit管理
        :mgit_excluded,

        # [Boolean] 是否是占位仓库【2.3.0废弃】
        :dummy,

        # [Boolean] 是否是配置仓库（包含配置表的仓库），若是，则某些操作如merge，checkout等会优先操作配置仓库，确保配置表最新
        :is_config_repo,

        # [Boolean] 是否锁定仓库（即任何操作均保证仓库状态与指定配置一致）
        :lock
    ) do

      # 根据解析内容拼接一个clone地址
      #
      # @param root [String] mgit根目录
      # @param local_url [String] default: nil 如果从本地clone，可传入一个本地的xxx.git实体地址
      #
      # @return [String] clone地址
      #
      def clone_url(root, local_url:nil, clone_branch:nil)
        url = local_url.nil? ? self.url : local_url

        if !clone_branch.nil? && Utils.branch_exist_on_remote?(clone_branch, url)
          branch_opt = "-b #{clone_branch}"
        elsif !self.branch.nil? && Utils.branch_exist_on_remote?(self.branch, url)
          branch_opt = "-b #{self.branch}"
        else
          branch_opt = ''
        end

        "git clone #{branch_opt} -- #{url} #{abs_dest(root)}"
      end

      # 生成绝对路径
      #
      # @param root [String] 多仓库根目录
      #
      # @return [String] 仓库绝对路径
      #
      def abs_dest(root)
        Utils.expand_path(self.path, base:root)
      end

      # 生成.git存储的完整路径
      #
      # @param root [String] 多仓库根目录
      #
      # @return [String] .git存储的完整路径
      #
      def git_store_dir(root)
        # 替换key值中的‘/’字符，避免和路径混淆
        name = self.name.gsub(/\//,':')

        # 删除冗余字符
        url = Utils.normalize_url(self.url)

        git_store = Utils.generate_git_store(root, url)
        if git_store.nil?
          git_dir = File.join(root, Constants::PROJECT_DIR[:source_git])
          git_store = File.join(git_dir, name)
        end

        git_store
      end

      # 生成缓存存放完整路径
      #
      # @param root [String] 多仓库根目录
      #
      # @return [String] 缓存存放完整路径
      #
      def cache_store_dir(root)
        File.join(git_store_dir(root), 'cache')
      end
    end
  end
end
