#coding=utf-8

require_relative 'utils'

module MGit
  class MGitConfig

    CONFIG_KEY = {
        :managegit  => {
            :info     => '是否将.git实体托管给MGit，托管后仓库内的.git目录是软链 (true/false)',
            :type     => 'Boolean',
            :default  => true
        },
        :maxconcurrentcount => {
            :info     => 'MGit操作的最大并发数? (Integer)',
            :type     => 'Integer',
            :default  => MGit::Utils.logical_cpu_num
        },
        :syncworkspace => {
            :info     => '是否按照配置表同步工作区? (true/false)',
            :type     => 'Boolean',
            :default  => true
        },
        :savecache => {
            :info     => '同步工作区时回收的仓库是否保留到缓存中? (true/false)',
            :type     => 'Boolean',
            :default  => false
        },
        :logenable => {
            :info     => '是否开启日志打印，操作日志会收集到.mgit/log目录下? (true/false)',
            :type     => 'Boolean',
            :default  => true
        },
        :loglevel => {
            :info     => '日志的打印级别, DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3, FATAL = 4',
            :type     => 'Integer',
            :default  => 1
        }
    }

    class << self

      # 查询配置
      #
      # @param root [String] 工程根目录
      #
      # @raise [MGit::Error] 异常错误
      #
      def query(root)
        config, error = __load_file(root)
        if !error.nil?
          raise Error.new(error)
          return
        elsif block_given?
          # 如果文件存在但无内容，此时读取到的数据类型是FalseClass，此处统一规范化
          config = {} if !config.is_a?(Hash)
          yield(config)
        end
      end

      # Description of #query_with_key
      #
      # @param root [String] 工程根目录
      #
      # @param key_symbol [Symbol] 符号key值
      #
      # @return [Object] 配置值
      #
      # @raise [MGit::Error] 异常错误
      def query_with_key(root, key_symbol)
        query(root) { |config|
          if !config[key_symbol.to_s].nil?
            return config[key_symbol.to_s]
          elsif !CONFIG_KEY[key_symbol].nil?
            return CONFIG_KEY[key_symbol][:default]
          else
            return nil
          end
        }
      end

      # 更新配置
      #
      # @param root [String] 工程根目录
      #
      # @raise [MGit::Error] 异常错误
      #
      def update(root)
        # 加载配置
        config, error = __load_file(root)
        if !error.nil?
          raise Error.new(error)
          return
        end

        # 如果文件存在但无内容，此时读取到的数据类型是FalseClass，此处统一规范化
        config = {} if !config.is_a?(Hash)

        # 更新
        yield(config) if block_given?

        # 更新完后校验格式
        if !config.is_a?(Hash)
          raise Error.new("工具配置更新数据格式错误，更新失败！")
          return
        end

        # 写回配置
        error = write_to_file(root, config)
        if !error.nil?
          raise Error.new(error)
          return
        end
      end

      # 列出所有配置
      #
      # @param root [String] 工程根目录
      #
      def dump_config(root)
        query(root) { |config|
          CONFIG_KEY.each_with_index { |(key, value_dict), index|
            line = "#{Output.blue_message("[#{value_dict[:info]}]")}\n#{key.to_s}: "
            set_value = config[key.to_s]
            if !set_value.nil?
              line += "#{set_value}\n\n"
            else
              line += "#{value_dict[:default]}\n\n"
            end
            puts line
          }
        }
      end

      # 验证一个value的值是否符合key的类型
      #
      # @param root [String] 工程根目录
      #
      # @param key [String] 字符串key值
      #
      # @param value [String] 字符串格式的值
      #
      # @return [Object] key值对应的合法类型value值
      #
      def to_suitable_value_for_key(root, key, value)
        return unless CONFIG_KEY.keys.include?(key.to_sym)
        return nil if !value.is_a?(String)

        key_dict = CONFIG_KEY[key.to_sym]
        set_value = nil

        # 是否是数字
        if key_dict[:type] == 'Integer' && value.to_i.to_s == value
          set_value = value.to_i

          # 是否是true
        elsif key_dict[:type] == 'Boolean' && value.to_s.downcase == 'true'
          set_value = true

          # 是否是false
        elsif key_dict[:type] == 'Boolean' && value.to_s.downcase == 'false'
          set_value = false

          # 是否是其他字符串
        elsif key_dict[:type] == 'String' && value.is_a?(String)
          set_value = value
        end

        set_value
      end

      private

      # 加载mgit配置文件
      #
      # @param root [String] 工程根目录
      #
      # @return [(Hash, Boolean)] (配置内容，错误信息)
      #
      def __load_file(root)
        config_path = File.join(root, Constants::MGIT_CONFIG_PATH)
        if File.exists?(config_path)
          begin
            return YAML.load_file(config_path), nil
          rescue => e
            return nil, "工具配置文件\"#{File.basename(config_path)}\"读取失败，原因：\n#{e.message}"
          end
        end

        [nil, nil]
      end

      # 将配置写回文件
      #
      # @param root [String] 工程根目录
      #
      # @param content [Hash] 新配置
      #
      # @return [String] 错误信息
      #
      def write_to_file(root, content)
        config_path = File.join(root, Constants::MGIT_CONFIG_PATH)
        begin
          FileUtils.rm_f(config_path) if File.exist?(config_path)

          dir_name = File.dirname(config_path)
          FileUtils.mkdir_p(dir_name) if !Dir.exist?(dir_name)

          file = File.new(config_path, 'w')
          if !file.nil?
            file.write(content.to_yaml)
            file.close
          end
          return nil
        rescue => e
          return "工具配置文件\"#{File.basename(config_path)}\"写入失败，原因：\n#{e.message}"
        end
      end
    end

  end
end
