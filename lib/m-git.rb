
$:.unshift __dir__

require 'open3'
require 'fileutils'
require 'json'
require 'digest'
require 'pathname'
require 'uri'
require 'yaml'
require 'securerandom'

require 'colored2'
require 'peach'
require 'tty-pager'

require 'm-git/foundation'
require 'm-git/output/output'
module MGit
  include MGit::Foundation
end

require 'm-git/argv'
require 'm-git/hooks_manager'
require 'm-git/command_manager'
require 'm-git/base_command'
require 'm-git/error'
require 'm-git/repo'
require 'm-git/manifest'
require 'm-git/template'
require 'm-git/version'
require 'm-git/workspace'

# 对外其他ruby脚本调用接口
require 'm-git/open_api'

# load plugin
require 'm-git/plugin_manager'


module MGit
  # 加载插件
  PluginManager.setup

  module_function
  # input
  def run(raw_argv)
    # 处理不带子命令或带全局参数的输入，如果带全局参数，目前版本对后续附加的子命令不处理。
    raw_argv.unshift('self') if (raw_argv.first.nil? || (raw_argv.first =~ /-/) == 0)
    need_verbose = raw_argv.delete('--verbose') || $__VERBOSE__ || false
    argv = ARGV::Parser.parse(raw_argv)

    begin
      # 特殊处理'base'
      cmd_class = CommandManager[argv.cmd]
      Foundation.help!("调用非法指令\"#{argv.cmd}\"") if cmd_class.nil?
      cmd_class.new(argv).run
    rescue => e
      Output.puts_fail_message("执行该指令时发生异常：#{argv.cmd}")
      Output.puts_fail_message("异常信息：#{e.message}")
      Output.puts_fail_message("异常位置：#{e.backtrace.join("\n")}") if need_verbose
      exit
    end
  end
end

