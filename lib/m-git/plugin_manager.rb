
module MGit
  class PluginManager

    # @!scope 加载插件
    # 1. 先加载本地源码插件
    # 2. 搜索加载gem插件
    # 3. 处理加载注入的插件
    #
    def self.setup
      lib_dir = File.dirname(__FILE__)
      plugins_dir = File.join(File.dirname(File.dirname(lib_dir)), 'plugins')
      load_local_plugin_dir('mgit', plugins_dir)
      load_local_plugin_dir('m-git', plugins_dir)
      load_gem_plugins('mgit')
      load_gem_plugins('m-git')

      inject_flag = '--inject='.freeze
      inject_arg = ::ARGV.find { |arg| arg.start_with?(inject_flag) }
      if inject_arg
        ::ARGV.delete(inject_arg)
        inject_file = inject_arg[inject_flag.length..-1]
        if !inject_file.start_with?('~') && !inject_file.start_with?('/')
          inject_file = File.join(Dir.pwd, inject_file)
        end
        inject_file = File.expand_path(inject_file)
        if File.exist?(inject_file)
          if File.file?(inject_file)
            require inject_file
          elsif File.directory?(inject_file)
            load_local_plugins('mgit', inject_file)
            load_local_plugins('m-git', inject_file)
          end
        end
      end
    end

    # 加载本地的plugin优先，然后加载gem的plugin
    # [Hash{String=> [String]}]
    #
    def self.loaded_plugins
      @loaded_plugins ||= {}
    end

    # 加载插件集合目录，该目录下每个文件夹遍历加载一次
    #
    def self.load_local_plugin_dir(plugin_prefix, plugins_dir)
      Dir.foreach(plugins_dir) do |file|
        next if file == '.' || file == '..' || file == '.DS_Store'
        plugin_root = File.join(plugins_dir, file)
        next unless File.directory?(plugin_root)
        load_local_plugins(plugin_prefix, plugin_root, file)
      end if Dir.exist?(plugins_dir)
    end

    # 加载单个本地插件
    #
    def self.load_local_plugins(plugin_prefix, plugin_root, with_name = nil)
      with_name ||= plugin_root
      glob = "#{plugin_prefix}_plugin#{Gem.suffix_pattern}"
      glob = File.join(plugin_root, '**', glob)
      plugin_files = Dir[glob].map { |f| f.untaint }
      return if loaded_plugins[with_name] || plugin_files.nil? || plugin_files.empty?
      safe_activate_plugin_files(with_name, plugin_files)
      loaded_plugins[with_name] = plugin_files
    end

    # 加载已安装的gem插件
    #
    def self.load_gem_plugins(plugin_prefix)
      glob = "#{plugin_prefix}_plugin#{Gem.suffix_pattern}"
      gem_plugins = Gem::Specification.latest_specs.map do |spec|
        matches = spec.matches_for_glob(glob)
        [spec, matches] unless matches.empty?
      end.compact

      gem_plugins.map do |spec, paths|
        next if loaded_plugins[spec.name]
        safe_activate_gem(spec, paths)
        loaded_plugins[spec.full_name] = paths
      end
    end

    def self.safe_activate_gem(spec, paths)
      spec.activate
      paths.each { |path| require(path) }
      true
    rescue Exception => exception # rubocop:disable RescueException
      message = "\n---------------------------------------------"
      message << "\n加载插件失败 `#{spec.full_name}`.\n"
      message << "\n#{exception.class} - #{exception.message}"
      message << "\n#{exception.backtrace.join("\n")}"
      message << "\n---------------------------------------------\n"
      warn message.ansi.yellow
      false
    end

    def self.safe_activate_plugin_files(plugin_name, paths)
      paths.each { |path| require(path) }
      true
    rescue Exception => exception
      message = "\n---------------------------------------------"
      message << "\n加载插件失败 `#{plugin_name}`.\n"
      message << "\n#{exception.class} - #{exception.message}"
      message << "\n#{exception.backtrace.join("\n")}"
      message << "\n---------------------------------------------\n"
      warn message.ansi.yellow
      false
    end

  end
end
