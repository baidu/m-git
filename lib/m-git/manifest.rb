#coding=utf-8

require 'm-git/manifest/light_repo'
require 'm-git/manifest/linter'
require 'm-git/manifest/internal'

module MGit

  # Sample: 'm-git/manifest/manifest.sample'
  #
  class Manifest
    include Linter
    include Internal

    # [Hash] 配置内容
    attr_reader :config

    # [String] 配置表内容哈希
    # attr_reader :config_hash
    attr_reader :hash_sha1

    # [Array<LightRepo>] 与config中‘repositories’字段对应的Manifest::LightRepo对象数组，包含git仓库和非git仓库
    attr_reader :light_repos

    # [Array<LightRepo>] 类型同light_repos，表示上次操作，但本次未操作的仓库
    attr_reader :previous_extra_light_repos

    # [LightRepo] 包含配置表的配置仓库
    attr_reader :config_repo

    # [String] 配置文件路径
    attr_reader :path

    # [String] 缓存文件路径
    attr_reader :cache_path

    # [Hash] 上次改动生成的配置缓存
    attr_reader :previous_config

    # 在mgit根目录中搜索配置文件并根据配置文件生成对应LightRepo对象。
    #
    # [!!!!!] 请勿随意修改该接口
    #
    # @param root [String] mgit工作区根目录
    #
    # @param mgit_managed_only [Boolean] default: false，是否只获取mgit管理的git仓库
    #
    # @param only_exist [Boolean] default: false，是否只获取实际存在的仓库
    #
    # @param exclude_dummy [Boolean] default: false，是否排除dummy仓库
    #
    # @return [Array<LightRepo>] 仓库列表
    #
    def self.generate_light_repos(root, mgit_managed_only: false, only_exist:false, exclude_dummy:false)
      config_path = File.join(root, Constants::PROJECT_DIR[:source_config])
      config = self.parse(config_path)

      if mgit_managed_only
        repos = config.repo_list
      elsif exclude_dummy
        repos = config.light_repos.select { |repo| !repo.dummy }
      else
        repos = config.light_repos
      end

      if only_exist
        existing_repos = []
        repos.each { |repo|
          abs_path = repo.abs_dest(root)
          # 被管理的仓库验证是否是git仓库，不被管理的仓库只验证文件夹是否存在
          if (repo.mgit_excluded && Dir.exist?(abs_path)) || (!repo.mgit_excluded && Repo.is_git_repo?(abs_path))
            existing_repos.push(repo)
          end
        }
        repos = existing_repos
      end

      return repos
    end

    # 全流程校验，除了字段合法性校验外，还包含缓存生成/校验，local配置文件校验/合并
    #
    # @param config_path [String] 配置文件本地路径
    #
    # @param strict_mode [Boolean] default: true 如果为true，出错直接报错退出，如果为false，出错抛出异常（MGit::Error）
    #
    # @return [Manifest] 配置对象
    #
    def self.parse(config_path, strict_mode:true)
      config = Manifest.new
      config.__setup(config_path, strict_mode)
      return config
    end

    # 简单校验，仅校验配置内容，无缓存生成/校验，无local配置文件校验/合并
    #
    # @param config_content [String/Hash] 配置表json字符串或字典(key值需为String)
    #
    # @param strict_mode [Boolean] default: true 如果为true，出错直接报错退出，如果为false，出错抛出异常（MGit::Error）
    #
    # @return [Manifest] 配置对象
    #
    def self.simple_parse(config_content, strict_mode:true)
      config = Manifest.new
      config.__simple_setup(config_content, strict_mode)
      return config
    end


    # 返回所有git仓库列表
    #
    # @param selection [Array<String>] default: nil，需要筛选的仓库名数组
    #
    # @param exclusion [Array<String>] default: nil，需要排除的仓库名数组
    #
    # @param all [Boolean] default: false 若指定为true，则忽略mgit_excluded的字段值，只要remote url存在（即有对应远程仓库），则选取
    #
    # @return [Array<LightRepo>] 被mgit管理的仓库生成的LightRepo数组
    #
    def repo_list(selection: nil, exclusion: nil, all:false)
      list = []
      light_repos.each { |light_repo|
        if !light_repo.mgit_excluded || (all && !light_repo.url.nil?)
          # 选取指定仓库
          if (selection.nil? && exclusion.nil?) ||
            (!selection.nil? && selection.is_a?(Array) && selection.any? { |e| e.downcase == light_repo.name.downcase }) ||
            (!exclusion.nil? && exclusion.is_a?(Array) && !exclusion.any? { |e| e.downcase == light_repo.name.downcase })
            list.push(light_repo)
          end
        end
      }
      list
    end

    # 获取全局配置
    #
    # @param key [Symbol] 配置字段【符号】
    #
    # @return [Object] 对应配置字段的值，可能是字符串，也可能是字典
    #
    def global_config(key)
      key_str = Constants::CONFIG_KEY[key]
      value = config[key_str]
      terminate!("无法获取多仓库配置必需字段\"#{key}\"的值!") if value.nil? && Constants::REQUIRED_CONFIG_KEY.include?(key_str)
      value
    end

    # 更新缓存
    #
    # @param root [String] 多仓库根目录
    #
    # @param config_content [Hash] 配置Hash
    #
    def update_cache_with_content(root, config_content)
      config_dir = File.join(root, Constants::PROJECT_DIR[:source_config])
      cache_path = File.join(config_dir, Constants::CONFIG_FILE_NAME[:manifest_cache])
      sha1 = __generate_hash_sha1(config_content.to_json)
      CacheManager.save_to_cache(cache_path, sha1, config_content)
    end

    # 更新（对比上次操作）冗余的轻量仓库对象
    #
    # @param root [String] 多仓库根目录
    #
    def update_previous_extra_light_repos(root)
      cache_path = File.join(root, Constants::PROJECT_DIR[:source_config],  Constants::CONFIG_FILE_NAME[:manifest_cache])
      __load_cache(cache_path)
    end

    def terminate!(msg, type:nil)
      if @strict_mode
        Foundation.help!(msg)
      else
        raise Error.new(msg, type:type)
      end
    end

  end

  RepoConfig = Manifest
end
