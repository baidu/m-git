
module MGit
  class Manifest
    module Linter

      # 校验配置文件路径
      #
      # @param path [Stirng] 配置文件路径或包含配置文件的目录
      #
      # @return [String] 配置文件合法路径
      #
      def lint_manifest_path(path)
        manifest_name = Constants::CONFIG_FILE_NAME[:manifest]

        if !File.exists?(path)
          if File.symlink?(path)
            terminate!("配置文件软链接#{path}失效，请执行\"mgit config -m <new_path>/manifest.json\"更新！")
          else
            terminate!("配置文件#{path}不存在！")
          end
        elsif File.basename(path) != manifest_name
          terminate!("请指定名为#{manifest_name}的文件！", type:MGIT_ERROR_TYPE[:config_name_error])
        end
      end

      # 校验本地配置文件路径
      #
      # @param path [String] 本地配置文件路径
      #
      # @return [String] 合法的本地配置文件路径
      #
      def lint_local_manifest_path(path)
        local_manifest_name = Constants::CONFIG_FILE_NAME[:local_manifest]
        terminate!("local配置文件#{path}不存在！") if !File.file?(path)
        terminate!("请指定名为#{local_manifest_name}的文件！", type:MGIT_ERROR_TYPE[:config_name_error]) if File.basename(path) != local_manifest_name
      end

      # @!scope 检查lightrepo的仓库url是否重复
      #
      def lint_light_repos!
        repo_urls = {}
        light_repos.each { |light_repo|
          next if light_repo.url.nil? || light_repo.url.length == 0
          repo_urls[light_repo.url] = [] if repo_urls[light_repo.url].nil?
          repo_urls[light_repo.url].push(light_repo.name)
        }

        error_repos = []
        repo_urls.each { |_, value|
          if value.length > 1
            error_repos += value
          end
        }

        if error_repos.length > 0
          puts Output.generate_table(error_repos, separator:'|')
          Foundation.help!("以上仓库url配置重复，请修改后重试！")
        end
      end

# 解析并校验配置文件
      def lint_raw_json!(dict)
        required_keys = Constants::REQUIRED_CONFIG_KEY
        missing_required_keys = required_keys - dict.keys
        terminate!("配置文件中缺失必需字段：#{missing_required_keys}") if missing_required_keys.length > 0

        valid_keys = Constants::CONFIG_KEY.values
        valid_repo_keys = Constants::REPO_CONFIG_KEY.values

        dict.each { |k, v|
          terminate!("配置文件中存在冗余字段：#{k}") unless valid_keys.include?(k)

          if k == Constants::CONFIG_KEY[:repositories]
            terminate!("配置文件中#{k}字段下的数据应为json格式！") if !dict[k].is_a?(Hash)

            config_repos = []
            dict[k].each { |repo_name, config|
              terminate!("配置文件中#{k}.#{repo_name}字段下的数据应为json格式！") if !config.is_a?(Hash)

              # 校验值类型
              config.each { |rk, rv|
                if rk == Constants::REPO_CONFIG_KEY[:mgit_excluded] ||
                    rk == Constants::REPO_CONFIG_KEY[:config_repo] ||
                    rk == Constants::REPO_CONFIG_KEY[:dummy]
                  terminate!("配置文件中#{k}.#{repo_name}.#{rk}字段下的数据应为Bool类型！") if !rv.is_a?(TrueClass) && !rv.is_a?(FalseClass)
                elsif rk == Constants::REPO_CONFIG_KEY[:lock]
                  terminate!("配置文件中#{k}.#{repo_name}.#{rk}字段下的数据应为Json类型！") if !rv.is_a?(Hash)
                elsif valid_repo_keys.include?(rk)
                  terminate!("配置文件中#{k}.#{repo_name}.#{rk}字段下的数据应为String类型！") if !rv.is_a?(String)
                end
              }

              # 如果mgit_excluded字段是false或者缺省，则纳入mgit多仓库管理，进行严格校验
              mgit_excluded = config[Constants::REPO_CONFIG_KEY[:mgit_excluded]]
              global_mgit_excluded = dict[Constants::CONFIG_KEY[:mgit_excluded]]

              if (mgit_excluded.nil? || mgit_excluded == false) && (global_mgit_excluded.nil? || global_mgit_excluded == false)
                # 校验仓库配置必须字段
                valid_required_repo_keys = Constants::REQUIRED_REPO_CONFIG_KEY # 不可缺省的字段
                missing_required_keys = valid_required_repo_keys - config.keys
                terminate!("配置文件中#{k}.#{repo_name}下有缺失字段:#{missing_required_keys.join(', ')}") if missing_required_keys.length > 0

                # 校验仓库配置冗余字段
                # extra_keys = config.keys - valid_repo_keys
                # terminate!("配置文件中#{k}.#{repo_name}下有冗余字段:#{extra_keys.join(', ')}") if extra_keys.length > 0

                # 统计指定的配置仓库
                config_repo = config[Constants::REPO_CONFIG_KEY[:config_repo]]
                if !config_repo.nil? && config_repo == true
                  config_repos.push(repo_name)
                end

                # 校验锁定点
                lock_key = Constants::REPO_CONFIG_KEY[:lock]
                lock_config = config[lock_key]
                if !lock_config.nil?
                  valid_lock_keys = Constants::REPO_CONFIG_LOCK_KEY.values

                  # 校验锁定点配置值
                  lock_config.each { |ck, cv|
                    terminate!("配置文件中#{k}.#{repo_name}.#{lock_key}.#{ck}字段下的数据应为String类型！") if !cv.is_a?(String)
                  }

                  # 校验锁定点配置必须字段
                  terminate!("配置文件中#{k}.#{repo_name}.#{lock_key}下只能指定字段:#{valid_lock_keys.join(', ')}中的一个！") if lock_config.keys.length != 1 || !valid_lock_keys.include?(lock_config.keys.first)

                  # 校验锁定点配置冗余字段
                  # extra_keys = lock_config.keys - valid_lock_keys
                  # terminate!("配置文件中#{k}.#{repo_name}.#{lock_key}下有冗余字段:#{extra_keys.join(', ')}") if extra_keys.length > 0

                end
              end
            }

            # 校验配置仓库字段的合法性
            if config_repos.length > 1
              puts Output.generate_table(config_repos)
              terminate!("配置表中同时指定了以上多个仓库为配置仓库，仅允许指定最多一个！")
            end
          elsif k == Constants::CONFIG_KEY[:version]
            terminate!("配置文件中#{k}字段下的数据应为Integer类型！") if !dict[k].is_a?(Integer)
          elsif k == Constants::CONFIG_KEY[:mgit_excluded]
            terminate!("配置文件中#{k}字段下的数据应为Boolean类型！") if !dict[k].is_a?(TrueClass) && !dict[k].is_a?(FalseClass)
          else
            terminate!("配置文件中#{k}字段下的数据应为String类型！") if !dict[k].is_a?(String)
          end
        }
      end

    end

  end
end
