#coding=utf-8

module MGit
  module Constants
    PROJECT_DIR = {
        :hooks          => '.mgit/hooks',
        :source_config  => '.mgit/source-config',
        :source_git     => '.mgit/source-git',
        :snapshot       => '.mgit/snapshot',
        :log_dir        => '.mgit/logs'
    }.freeze

    HOOK_NAME = {
        :pre_hook            => 'pre_hook.rb',
        :post_hook           => 'post_hook.rb',
        :manifest_hook       => 'manifest_hook.rb',
        :post_download_hook  => 'post_download_hook.rb',
        :pre_push_hook       => 'pre_push_hook.rb',
        :pre_exec_hook       => 'pre_exec_hook.rb'
    }.freeze

    MGIT_CONFIG_PATH = ".mgit/config.yml"

    CONFIG_FILE_NAME = {
        :manifest       => 'manifest.json',
        :manifest_cache => '.manifest_cache.json',
        :local_manifest => 'local_manifest.json'
    }.freeze

    # 全局配置
    CONFIG_KEY = {
        # [String] 包含仓库的文件夹相对.mgit目录路径，完整路径如：<.mgit所在路径>/dest/<repo_name>，与abs-dest同时指定时无效
        :dest           => 'dest',
        # [Boolean] 是否将所有仓库排除mgit管理
        :mgit_excluded  => 'mgit-excluded',
        # [String] 远程仓库根目录，完整URL：remote/remote_path
        :remote         => 'remote',
        # [String] 远程仓库相对目录，完整URL：remote/remote_path
        :repositories   => 'repositories',
        # [String] mgit版本
        :version        => 'version',
    }.freeze

    # 仓库配置
    REPO_CONFIG_KEY = {
        # [String] 仓库完整路径
        :abs_dest       => 'abs-dest',
        # [Boolean] 是否是配置仓库
        :config_repo    => 'config-repo',
        # [String] 包含仓库的文件夹相对.mgit目录路径，完整路径如：<.mgit所在路径>/dest/<repo_name>，与abs-dest同时指定时无效
        :dest           => 'dest',
        # [Boolean] 是否是占位仓库，占位操作不会让mgit进行常规操作（隐含指定mgit_excluded为true），标记为占位的仓库组装器组装时不需要使用
        :dummy          => 'dummy',
        # [Json] 锁定状态，见REPO_CONFIG_LOCK_KEY
        :lock           => 'lock',
        # [Boolean] 是否排除mgit管理，被排除的仓库不会让mgit进行常规操作，若未标记dummy，则为不被mgit管理，但组装器需要的仓库
        :mgit_excluded  => 'mgit-excluded',
        # [String] 远程仓库根目录，完整URL：remote/remote_path
        :remote         => 'remote',
        # [String] 远程仓库相对目录，完整URL：remote/remote_path
        :remote_path    => 'remote-path'
    }.freeze

    # 必须全局字段
    REQUIRED_CONFIG_KEY = [
        CONFIG_KEY[:remote],
        CONFIG_KEY[:version],
        CONFIG_KEY[:dest],
        CONFIG_KEY[:repositories]
    ].freeze

    # 必须仓库配置字段
    REQUIRED_REPO_CONFIG_KEY = [
        REPO_CONFIG_KEY[:remote_path],
    ].freeze

    REPO_CONFIG_LOCK_KEY = {
        :branch         => 'branch',
        :commit_id      => 'commit-id',
        :tag            => 'tag'
    }.freeze

    SNAPSHOT_KEY = {
        :time_stamp     => 'time-stamp',
        :message        => 'message',
        :snapshot       => 'snapshot'
    }.freeze

    CONFIG_CACHE_KEY = {
        :hash           => 'hash',
        :cache          => 'cache'
    }.freeze

    # 定义字段用于调用git（shell）指令前export，便于仓库git hook区分来进行其余操作
    MGIT_EXPORT_INFO = {
        # 是否是MGit操作的git指令
        :MGIT_TRIGGERRED  =>  1,
        # 本次MGit操作的唯一标示
        :MGIT_OPT_ID      =>  SecureRandom.uuid
    }.freeze

    # 临时中央仓库名
    CENTRAL_REPO = "Central".freeze

    INIT_CACHE_DIR_NAME = "pmet_tini_tigm".freeze
  end
end
