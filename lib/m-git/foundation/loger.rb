#coding=utf-8

require 'logger'
require 'fileutils'
module MGit

  # 日志模块配置
  class Loger

    MGIT_LOG_FILE_NAME = 'mgit.log'

    #
    # 配置Log模块
    #
    # @param root [String] 工程根目录
    #
    def self.config(root)
      # 是否开启log
      begin
        log_enable = MGit::MGitConfig.query_with_key(root, :logenable)
      rescue MGitClass::Error => e
        log_enable = TRUE
      end
      MGit::Loger.set_log_enable(log_enable)

      # 配置log路径
      log_dir = File.join(root, MGit::Constants::PROJECT_DIR[:log_dir])
      FileUtils.mkdir_p(log_dir) if !Dir.exist?(log_dir)
      file_path = File.join(log_dir, MGIT_LOG_FILE_NAME)
      MGit::Loger.set_log_file(file_path)

      # 配置log的level
      begin
        log_level = MGit::MGitConfig.query_with_key(root, :loglevel)
      rescue MGitClass::Error => e
        log_level = 1
      end
      MGit::Loger.set_log_level(log_level)

    end

  end


  # 日志模块
  class Loger
    DEFAULT_SHIFT_SIZE = 1048576  #每个文件1M
    DEFAULT_SHIFT_AGE = 10 # 保留10个文件
    DEFAULT_LOG_FILE = "./mgit.log"

    #
    # 设置mgit log是否开启 默认开启
    #
    # @param log_enable [Boolean] 是否开启log日志
    #
    def self.set_log_enable(log_enable)
      @log_enable = log_enable
    end

    #
    # 设置mgit log的打印等级
    #
    # @param level [Enumerable]: Logger::DEBUG | Logger::INFO | Logger::ERROR | Logger::FATAL
    #
    def self.set_log_level(level)
      self.logger.level = level
    end

    #
    # 设置mgit log的文件名， 默认路径在工作区的 .mgit/logs/mgit.log
    #
    def self.set_log_file(file_path)
      @log_file = file_path
    end

    #
    # 打印 DEBUG类型的log
    #
    def self.debug(message)
      self.logger.debug(message) if @log_enable
    end

    #
    # 打印 DEBUG类型的log
    #
    def self.info(message)
      self.logger.info(message) if @log_enable
    end

    #
    # 打印 WARN类型的log
    #
    def self.warn(message)
      self.logger.warn(message) if @log_enable
    end

    #
    # 打印 ERROR类型的log
    #
    def self.error(message)
      self.logger.error(message) if @log_enable
    end

    #
    # 打印 FATAL类型的log
    #
    def self.fatal(message)
      self.logger.fatal(message) if @log_enable
    end

    private
    def self.logger
      unless @logger
        @log_enable ||= TRUE
        @log_level ||= Logger::INFO
        @log_file ||= DEFAULT_LOG_FILE
        @logger = Logger.new(@log_file, shift_age = DEFAULT_SHIFT_AGE, shift_size = DEFAULT_SHIFT_SIZE)
        @logger.level = @log_level
        @logger.datetime_format = '%Y-%m-%d %H:%M:%S'
        @logger.formatter = proc do | severity, datetime, progname, msg|
          "#{datetime} - #{severity} - : #{msg}\n"
        end
      end
      @logger
    end

  end

end
