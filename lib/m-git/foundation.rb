#coding=utf-8

require 'm-git/foundation/constants'
require 'm-git/foundation/dir'
require 'm-git/foundation/git_message_parser'
require 'm-git/foundation/lock'
require 'm-git/foundation/loger'
require 'm-git/foundation/duration_recorder'
require 'm-git/foundation/mgit_config'
require 'm-git/foundation/operation_progress_manager'
require 'm-git/foundation/timer'
require 'm-git/foundation/utils'

module MGit
  module Foundation

    class << self
      # 异常终止
      def help!(msg, title:nil)
        Output.puts_terminate_message(msg, title:title)
        exit
      end
    end
  end
end