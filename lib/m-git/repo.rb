#coding=utf-8

require 'm-git/repo/status'
require 'm-git/repo/sync_helper'

module MGit

  class Repo

    # 仓库名
    attr_reader :name

    # 仓库实体完整路径
    attr_reader :path

    # 仓库状态检查器
    attr_reader :status_checker

    # 配置文件中的设置：Manifest::LightRepo
    attr_reader :config

    def initialize(name, path, config:nil)
      @name = name
      @path = path
      @config = config
      @status_checker = Status.new(path)
    end

    # 根据传入的绝对路径生成repo对象，如果传入路径不对应git仓库，则返回nil
    # return [(Repo, String)] (repo, error_message)
    def self.generate_softly(root, config)
      abs_path = config.abs_dest(root)
      if self.is_git_repo?(abs_path)
        repo = Repo.new(config.name, config.abs_dest(root), config:config)
        return repo, nil
      else
        return nil, "路径位置\"#{abs_path}\"不是git仓库！"
      end
    end

    # 根据传入的绝对路径生成repo对象，如果传入路径不对应git仓库，则抛出异常
    def self.generate_strictly(root, config)
      abs_path = config.abs_dest(root)
      if self.is_git_repo?(abs_path)
        return Repo.new(config.name, config.abs_dest(root), config:config)
      elsif File.directory?(abs_path)
        Foundation.help!("路径位置\"#{abs_path}\"不是git仓库！请先确认并手动删除该文件夹，然后执行\"mgit sync -n\"重新下载。")
      else
        # （注意，如果不希望被同步仓库的.git实体被mgit管理，请执行\"mgit sync -n -o\"，该方式将不会把.git实体放置到.mgit/souce-git中，更适合开发中途接入mgit的用户）
        Foundation.help!("路径位置\"#{abs_path}\"不是git仓库！请执行\"mgit sync -n\"重新下载。")
      end
    end

    def self.check_git_dest(root, config)
      abs_path = config.abs_dest(root)
      if self.is_git_repo?(abs_path)
        true
      elsif File.directory?(abs_path)
        Foundation.help!("路径位置\"#{abs_path}\"不是git仓库！请先确认并手动删除该文件夹，然后执行\"mgit sync -n\"重新下载。")
      else
        false
      end
    end

    # 检查传入路径是不是git仓库
    #
    # @param path [String] 仓库路径
    #
    def self.is_git_repo?(path)
      Dir.is_git_repo?(path)
    end

    # 对仓库执行shell指令的入口
    #
    # @param abs_cmd [String] 完整指令
    #
    # @return [Boolean,String] 是否成功；输出结果
    #
    def execute(abs_cmd)
      Timer.start(name, use_lock:true)
      Utils.execute_shell_cmd(abs_cmd) { |stdout, stderr, status|
        # 标记状态更新
        @status_checker.refresh

        Timer.stop(name, use_lock:true)
        if status.success?
          output = stdout.nil? || stdout.length == 0 ? stderr : stdout
          return true, output
        else
          output = stderr.nil? || stderr.length == 0 ? stdout : stderr
          return false, output
        end
      }
    end

    # 对仓库执行git指令的入口
    def execute_git_cmd(cmd, opts)
      return execute(git_cmd(cmd, opts))
    end

    # 对git指令进行加工，指定正确的执行目录
    def git_cmd(cmd, opts)
      git_dir = File.join(@path, '.git')

      # 组装导出变量
      export_pair = nil
      Constants::MGIT_EXPORT_INFO.each { |k,v|
        if !export_pair.nil?
          export_pair += " #{k.to_s}=#{v}"
        else
          export_pair = "export #{k.to_s}=#{v}"
        end
      }
      export_pair += " && " if !export_pair.nil?

      return "#{export_pair}git --git-dir=\"#{git_dir}\" --work-tree=\"#{@path}\" #{cmd} #{opts}"
    end

    # 判断实际url和配置url是否一致
    #
    # @return [Boolean] 是否一致
    #
    def url_consist?
      if !self.config.nil?
        return Utils.url_consist?(self.status_checker.default_url, self.config.url)
      else
        return true
      end
    end

  end

end
