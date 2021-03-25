
require 'm-git/manifest/cache_manager'

module MGit
  class Manifest
    module Internal


      # 配置对象
      #
      # @param config_path [String] 配置文件路径或目录
      #
      # @param strict_mode [Boolean] 是否使用严格模式。在严格模式下，出错将终止执行。在非严格模式下，出错将抛出异常，程序有机会继续执行。
      #
      def __setup(config_path, strict_mode)
        @strict_mode = strict_mode
        if File.directory?(config_path)
          config_dir = config_path
          config_path = File.join(config_dir, Constants::CONFIG_FILE_NAME[:manifest])
        else
          config_dir = File.dirname(config_path)
          config_path = File.join(config_dir, File.basename(config_path))
        end

        local_path = File.join(config_dir, Constants::CONFIG_FILE_NAME[:local_manifest])
        cache_path = File.join(config_dir, Constants::CONFIG_FILE_NAME[:manifest_cache])

        __load_config(config_path, local_config_path: local_path, cache_path: cache_path)
      end

      # 简单配置对象，部分属性为nil
      #
      # @param config_content [Hash] 配置Hash
      #
      # @param strict_mode [Boolean] 是否使用严格模式。在严格模式下，出错将终止执行。在非严格模式下，出错将抛出异常，程序有机会继续执行。
      #
      def __simple_setup(config_content, strict_mode)
        @strict_mode = strict_mode

        if config_content.is_a?(Hash)
          @config = config_content.deep_clone
        else
          @config = JSON.parse(config_content)
        end
        lint_raw_json!(config)

        @light_repos = __generate_light_repos(config)
        @config_repo = light_repos.find { |light_repo| light_repo.is_config_repo }

        # 计算配置文件哈希
        @hash_sha1 = __generate_hash_sha1(config.to_json)
      end


      private

      def cache_manager
        @cache_manager ||= CacheManager.new
      end


      # 加载配置文件
      #
      def __load_config(config_path, config_content: nil, local_config_path: nil, cache_path: nil)
        if config_content
          config_hash = __parse_manifest_json(config_content)
        else
          # 校验配置文件路径
          lint_manifest_path(config_path)

          # 读取配置文件
          config_hash = __parse_manifest(config_path)
        end

        lint_raw_json!(config_hash)

        if local_config_path && File.exist?(local_config_path)
          lint_local_manifest_path(local_config_path)
          local_config_hash = __parse_manifest(local_config_path)

          __merge_manifest_hash(config_hash, local_config_hash)
        end

        @light_repos = __generate_light_repos(config_hash)
        @config_repo = light_repos.find { |light_repo| light_repo.is_config_repo }
        lint_light_repos!

        @path = config_path
        @config = config_hash
        # 计算配置文件哈希
        @hash_sha1 = __generate_hash_sha1(config_hash.to_json)

        __load_cache(cache_path)
        if previous_config.nil? || previous_config != config_hash
          # 更新缓存
          @cache_path = cache_path
          @previous_config = config
          CacheManager.save_to_cache(cache_path, hash_sha1, config)
        end
      end

      def __load_cache(cache_path)
        if cache_path && File.exist?(cache_path)
          cache_manager.load_path(cache_path)
          @cache_path = cache_manager.path
          @previous_config = cache_manager.hash_data

          @previous_extra_light_repos = __generate_extra_light_repos(config, previous_config)
        end
      end

      def __parse_manifest_json(raw_string)
        begin
          raw_json = JSON.parse(raw_string)
        rescue => _
          terminate!("manifest文件解析错误，请检查json文件格式是否正确！")
        end

        raw_json
      end

      def __parse_manifest(path)
        begin
          raw_string = File.read(path)
        rescue => e
          terminate!("配置文件#{path}读取失败：#{e.message}")
        end
        __parse_manifest_json(raw_string)
      end

      def __generate_light_repos(config_hash)
        light_repos = []
        repositories = config_hash[Constants::CONFIG_KEY[:repositories]]
        repositories.each do |repo_name, repo_cfg|
          light_repos << LightRepoGenerator.light_repo_with(repo_name, repo_cfg, config_hash)
        end
        light_repos
      end

      def __generate_extra_light_repos(current_hash, previous_hash)
        return if previous_hash.nil?
        extra_light_repos = []
        repositories = current_hash[Constants::CONFIG_KEY[:repositories]]
        previous_repos = previous_hash[Constants::CONFIG_KEY[:repositories]]
        extra_keys = previous_repos.keys - repositories.keys
        extra_keys.each do |repo_name|
          extra_light_repos << LightRepoGenerator.light_repo_with(repo_name, previous_repos[repo_name], previous_hash)
        end
        extra_light_repos
      end


      # 计算配置文件的哈希
      def __generate_hash_sha1(json_string)
        begin
          return Digest::SHA256.hexdigest(json_string)
        rescue => e
          terminate!("配置文件哈希计算失败：#{e.message}")
        end
      end

      def __merge_manifest_hash(base_hash, attach_hash)
        dict = base_hash
        attach_hash.each { |key, value|
          if key == Constants::CONFIG_KEY[:repositories] && value.is_a?(Hash)
            dict[key] = {} if dict[key].nil?
            value.each { |repo_name, config|
              dict[key][repo_name] = {} if dict[key][repo_name].nil?
              if config.is_a?(Hash)
                config.each { |r_key, r_value|
                  dict[key][repo_name][r_key] = r_value if Constants::REPO_CONFIG_KEY.values.include?(r_key)
                }
              end
            }
          elsif Constants::CONFIG_KEY.values.include?(key)
            dict[key] = value
          end
        }
      end
    end
  end
end
