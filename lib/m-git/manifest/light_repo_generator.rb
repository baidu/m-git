
module MGit
  class Manifest
    # @!scope lightrepo生成器
    #
    class LightRepoGenerator

      # 简单初始化，有写字段缺失，仅包含名字，相对路径，url
      #
      # @param name [String] 仓库名
      #
      # @param path [String] 仓库相对路径
      #
      # @param url [String] 仓库url
      #
      # @return [LightRepo] 配置对象
      #
      def self.simple_init(name, path, url)
        LightRepo.new(name, path, nil, nil, nil, url, false, false, false, false)
      end

      def self.light_repo_with(name, config_json, parent_json)
        light_repo = LightRepo.new(name)

        light_repo.path = __parse_path(name, config_json, parent_json)
        lock_info = config_json[Constants::REPO_CONFIG_KEY[:lock]]

        light_repo.lock = lock_info && !lock_info.empty?
        if light_repo.lock
          light_repo.commit_id = lock_info[Constants::REPO_CONFIG_LOCK_KEY[:commit_id]]
          light_repo.tag = lock_info[Constants::REPO_CONFIG_LOCK_KEY[:tag]]
          light_repo.branch = lock_info[Constants::REPO_CONFIG_LOCK_KEY[:branch]]
        end
        light_repo.url = __parse_url(config_json, parent_json)

        dummy = config_json[Constants::REPO_CONFIG_KEY[:dummy]]
        dummy = !dummy.nil? && dummy == true
        if dummy
          excluded = true
        else
          excluded = config_json[Constants::REPO_CONFIG_KEY[:mgit_excluded]]
          excluded = parent_json[Constants::CONFIG_KEY[:mgit_excluded]] if excluded.nil?
          excluded = !excluded.nil? && excluded == true
        end
        light_repo.mgit_excluded = excluded
        light_repo.dummy = dummy

        is_config_repo = config_json[Constants::REPO_CONFIG_KEY[:config_repo]]
        light_repo.is_config_repo = is_config_repo.nil? ? false : is_config_repo
        light_repo
      end

      private

      class << self
        def __parse_path(repo_name, config_json, parent_json)
          abs_path = config_json[Constants::REPO_CONFIG_KEY[:abs_dest]]
          return abs_path if !abs_path.nil? && !abs_path.empty?

          local_path = parent_json[Constants::REPO_CONFIG_KEY[:dest]]
          # 替换key值中的‘/’字符，避免和路径混淆
          repo_name = repo_name.gsub(/\//,':')
          if local_path.nil?
            Utils.safe_join(parent_json[Constants::CONFIG_KEY[:dest]], repo_name)
          elsif !local_path.empty?
            Utils.safe_join(local_path, repo_name)
          else
            repo_name
          end
        end

        def __parse_url(config_json, parent_json)
          source_remote = config_json[Constants::REPO_CONFIG_KEY[:remote]]
          remote_path = config_json[Constants::REPO_CONFIG_KEY[:remote_path]]
          return if remote_path.nil?
          if source_remote.nil?
            global_remote = parent_json[Constants::CONFIG_KEY[:remote]]
            Utils.safe_join(global_remote, remote_path)
          else
            Utils.safe_join(source_remote, remote_path)
          end
        end
      end

    end
  end
end
