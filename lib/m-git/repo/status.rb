#coding=utf-8

module MGit
  class Repo
    class Status

      # https://git-scm.com/docs/git-status
      # status格式：XY PATH, X表示暂存区状态，Y表示工作区状态，在merge冲突的情况下，XY为冲突两边状态，未跟踪文件为??，忽略文件为!!。
      # 如：
      # MM some_file
      #  M some_file
      # M  some_file
      #
      # 其中：
      # ' ' = unmodified
      # M = modified
      # A = added
      # D = deleted
      # R = renamed
      # C = copied
      # U = updated but unmerged

      # 具体规则：
      # X          Y     Meaning
      # -------------------------------------------------
      #   [AMD]   not updated
      # M        [ MD]   updated in index
      # A        [ MD]   added to index
      # D                deleted from index
      # R        [ MD]   renamed in index
      # C        [ MD]   copied in index
      # [MARC]           index and work tree matches
      # [ MARC]     M    work tree changed since index
      # [ MARC]     D    deleted in work tree
      # [ D]        R    renamed in work tree
      # [ D]        C    copied in work tree
      # -------------------------------------------------
      # D           D    unmerged, both deleted
      # A           U    unmerged, added by us
      # U           D    unmerged, deleted by them
      # U           A    unmerged, added by them
      # D           U    unmerged, deleted by us
      # A           A    unmerged, both added
      # U           U    unmerged, both modified
      # -------------------------------------------------
      # ?           ?    untracked
      # !           !    ignored
      # -------------------------------------------------

      FILE_STATUS = {
          :unmodified     =>  ' ',
          :modified       =>  'M',
          :added          =>  'A',
          :deleted        =>  'D',
          :renamed        =>  'R',
          :copied         =>  'C'
      }.freeze

      FILE_STATUS_CONFLICT = {
          :both_deleted   => 'DD',
          :we_added       => 'AU',
          :they_deleted   => 'UD',
          :they_added     => 'UA',
          :we_deleted     => 'DU',
          :both_added     => 'AA',
          :both_modified  => 'UU'
      }.freeze

      FILE_STATUS_SPECIAL = {
          :untracked      => '??',
          :ignored        => '!!'
      }.freeze

      FILE_STATUS_MESSAGE = {
          FILE_STATUS[:unmodified].to_s               =>  nil,
          FILE_STATUS[:modified].to_s                 => '[已修改]',
          FILE_STATUS[:added].to_s                    => '[已添加]',
          FILE_STATUS[:deleted].to_s                  => '[已删除]',
          FILE_STATUS[:renamed].to_s                  => '[重命名]',
          FILE_STATUS[:copied].to_s                   => '[已拷贝]',
          FILE_STATUS_CONFLICT[:both_deleted].to_s    => '[删除|删除]',
          FILE_STATUS_CONFLICT[:we_added].to_s        => '[添加|修改]',
          FILE_STATUS_CONFLICT[:they_deleted].to_s    => '[修改|删除]',
          FILE_STATUS_CONFLICT[:they_added].to_s      => '[修改|添加]',
          FILE_STATUS_CONFLICT[:we_deleted].to_s      => '[删除|修改]',
          FILE_STATUS_CONFLICT[:both_added].to_s      => '[添加|添加]',
          FILE_STATUS_CONFLICT[:both_modified].to_s   => '[修改|修改]',
          FILE_STATUS_SPECIAL[:untracked].to_s        => '[未跟踪]',
          FILE_STATUS_SPECIAL[:ignored].to_s          => '[被忽略]'
      }.freeze

      STATUS_TYPE = {
          :normal         => 1,
          :conflicts      => 2,
          :special        => 3
      }.freeze

      GIT_REPO_STATUS = {
          :clean          =>  'clean',
          :dirty          =>  'dirty'
      }.freeze

      GIT_REPO_STATUS_DIRTY_ZONE = {
          :index          =>  1,      # 暂存区
          :work_tree      =>  1 << 1, # 工作区
          :special        =>  1 << 2  # 未跟踪和被ignore
      }.freeze

      GIT_BRANCH_STATUS = {
          :ahead          =>  'ahead',
          :behind         =>  'behind',
          :detached       =>  'detached',
          :diverged       =>  'diverged',
          :no_remote      =>  'no_remote',
          :no_tracking    =>  'no_tracking',
          :up_to_date     =>  'up_to_date'
      }.freeze

      def initialize(path)
        @path = path
        @status, @message = nil, nil
        @branch_status, @branch_message, @dirty_zone = nil, nil, nil
      end

      def status
        check_repo_status if @status.nil?
        return @status
      end

      def message
        check_repo_status if @message.nil?
        return @message
      end

      def dirty_zone
        check_repo_status if @dirty_zone.nil?
        return @dirty_zone
      end

      def branch_status
        check_branch_status if @branch_status.nil?
        return @branch_status
      end

      def branch_message
        check_branch_status if @branch_message.nil?
        return @branch_message
      end

      # 是否处于merge中间态
      def is_in_merge_progress?
        cmd = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" merge HEAD"
        Utils.execute_shell_cmd(cmd) { |stdout, stderr, status|
          return !status.success?
        }
      end

      # 是否处于rebase中间态
      def is_in_rebase_progress?
        cmd = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" rebase HEAD"
        Utils.execute_shell_cmd(cmd) { |stdout, stderr, status|
          return !status.success?
        }
      end

      # 当前分支是否是某个分支的祖先
      def is_ancestor_of_branch?(branch)
        c_branch = current_branch
        cmd  = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" merge-base --is-ancestor #{c_branch} #{branch}"
        cmd2 = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" rev-parse --verify #{branch}"
        cmd3 = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" rev-parse --verify #{c_branch}"

        is_ancestor = false
        Utils.execute_shell_cmd(cmd) { |stdout, stderr, status|
          is_ancestor = status.success?
        }

        # 当两个分支指向同一个commit的时候，“merge-base --is-ancestor”指令依然返回true，这里判断如果是这样当情况，就返回false
        if is_ancestor
          branch_hash = nil
          Utils.execute_shell_cmd(cmd2) { |stdout, stderr, status|
            branch_hash = stdout.chomp if status.success?
          }

          c_branch_hash = nil
          Utils.execute_shell_cmd(cmd3) { |stdout, stderr, status|
            c_branch_hash = stdout.chomp if status.success?
          }
          return !branch_hash.nil? && !c_branch_hash.nil? && branch_hash != c_branch_hash
        else
          return false
        end
      end

      # 查询追踪的远程分支
      #
      # @param branch [String] 查询分支
      #
      # @param use_cache [Boolean] default: false，是否使用缓存
      #
      # @return [String] 追踪的远程分支
      #
      def tracking_branch(branch, use_cache:false)
        return @tracking_branch if use_cache && !@tracking_branch.nil?

        cmd = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" rev-parse --abbrev-ref #{branch}@{u}"
        Utils.execute_shell_cmd(cmd) { |stdout, stderr, status|
          if status.success?
            @tracking_branch = stdout.chomp
            return @tracking_branch
          end
          return nil
        }
      end

      # 查询当前分支
      #
      # @param strict_mode [Boolean] default: true，是否是严格模式。在严格模式下，失败即终止。在非严格模式下，失败返回nil。
      #
      # @param use_cache [Boolean] default: false，是否使用缓存
      #
      # @return [String] 当前分支，查询失败或游离返回nil
      #
      def current_branch(strict_mode:true, use_cache:false)
        return @current_branch if use_cache && !@current_branch.nil?

        cmd = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" symbolic-ref --short -q HEAD"
        Utils.execute_shell_cmd(cmd) { |stdout, stderr, status|
          if status.success?
            @current_branch = stdout.chomp
            return @current_branch
          elsif strict_mode
            Foundation.help!("仓库#{File.basename(@path)}当前分支查询失败：当前HEAD不指向任何分支！")
          else
            return nil
          end
        }
      end

      # 查询当前HEAD指向的commit
      #
      # @param strict_mode [Boolean] default: true，是否是严格模式。在严格模式下，失败即终止。在非严格模式下，失败返回nil。
      #
      # @return [String] commit id
      #
      def current_head(strict_mode:true)
        cmd = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" rev-parse --short HEAD"
        Utils.execute_shell_cmd(cmd) { |stdout, stderr, status|
          if status.success?
            return stdout.chomp
          elsif strict_mode
            Foundation.help!("仓库#{File.basename(@path)}HEAD指向查询失败：#{stderr}")
          else
            return nil
          end
        }
      end

      # 指定分支本地是否存在
      def local_branch_exist?(branch)
        return has_branch?(branch, false)
      end

      # 指定分支是否存在对应远程分支（origin）
      def remote_branch_exist?(branch)
        return has_branch?(branch, true)
      end

      # commit是否存在
      def commit_exist?(commit)
        cmd = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" cat-file -t #{commit}"
        Utils.execute_shell_cmd(cmd) { |stdout, stderr, status|
          return status.success?
        }
      end

      # 查询仓库url
      def default_url
        cmd = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" config remote.origin.url"
        Utils.execute_shell_cmd(cmd) { |stdout, stderr, status|
          if status.success?
            return stdout.chomp
          else
            return nil
          end
        }
      end

      # 清空所有缓存内容
      def refresh
        @status, @message = nil, nil
        @branch_status, @branch_message = nil, nil
        @dirty_zone = 0
      end

      private

      # 拼接.git在工作区的路径
      def git_dir
        return File.join(@path, '.git')
      end

      # 返回工作区路径
      def work_tree
        return @path
      end

      # 分支是否存在
      #
      # @param branch [String] 查询分支
      #
      # @param is_remote [Boolean] 是否查询远程，若是，则查询origin/<branch>，否则仅查询<branch>
      #
      def has_branch?(branch, is_remote)
        return false if branch.nil?

        # 如果检查分支是当前分支（格式为"* current_branch"），后续检查会失效，因此直接返回true
        return true if branch == current_branch(strict_mode:false) && !is_remote

        padding = "  " # 终端输出的分支名前有两个空格
        cmd = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" branch #{is_remote ? '-r ' : ''}| grep -xi \"#{padding}#{is_remote ? 'origin/' : ''}#{branch}\""
        Utils.execute_shell_cmd(cmd) { |stdout, stderr, status|
          return status.success?
        }
      end

      # 查询仓库状态
      def check_repo_status
        cmd = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" status --porcelain"
        Utils.execute_shell_cmd(cmd) { |stdout, stderr, status|
          if status.success?
            if stdout.length > 0
              @status, @message, @dirty_zone = parse_change(stdout.split("\n"))
            else
              @status = GIT_REPO_STATUS[:clean]
              @message = [["仓库状态", ['无改动']]]
            end
          else
            Foundation.help!("仓库#{File.basename(@path)}状态查询失败：#{stderr}")
          end
        }
      end

      # 查询分支状态
      def check_branch_status
        branch = current_branch(strict_mode:false)
        remote_branch = tracking_branch(branch)
        is_tracking = !remote_branch.nil?

        # 当前HEAD不指向任何分支
        if branch.nil?
          @branch_status = GIT_BRANCH_STATUS[:detached]
          @branch_message = "当前HEAD处于游离状态"
          # 当前已经追踪远程分支
        elsif is_tracking
          cmd1 = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" rev-list #{branch}..#{remote_branch}"
          cmd2 = "git --git-dir=\"#{git_dir}\" --work-tree=\"#{work_tree}\" rev-list #{remote_branch}..#{branch}"
          stdout1, stdout2 = nil, nil

          Utils.execute_shell_cmd(cmd1) { |stdout, stderr, status|
            if status.success?
              stdout1 = stdout
            else
              Foundation.help!("检查仓库clean细节时，执行#{cmd1}命令失败：#{stderr}")
            end
          }.execute_shell_cmd(cmd2) { |stdout, stderr, status|
            if status.success?
              stdout2 = stdout
            else
              Foundation.help!("检查仓库clean细节时，执行#{cmd2}命令失败：#{stderr}")
            end
          }

          if stdout1.length == 0 && stdout2.length == 0
            @branch_status = GIT_BRANCH_STATUS[:up_to_date]
            @branch_message = "当前分支与远程分支[同步]"
          elsif stdout1.length == 0 && stdout2.length > 0
            @branch_status = GIT_BRANCH_STATUS[:ahead]
            # @branch_message = "当前分支超前远程分支[#{stdout2.split("\n").length}]个提交"
            @branch_message = "当前分支[超前]远程分支"
          elsif stdout1.length > 0 && stdout2.length == 0
            @branch_status = GIT_BRANCH_STATUS[:behind]
            # @branch_message = "当前分支落后远程分支[#{stdout1.split("\n").length}]个提交"
            @branch_message = "当前分支[落后]远程分支"
          elsif stdout1.length > 0 && stdout2.length > 0
            @branch_status = GIT_BRANCH_STATUS[:diverged]
            @branch_message = "当前分支与远程分支产生[分叉]"
          end
        elsif has_branch?(branch, true)
          # 有默认远程分支，但尚未追踪
          @branch_status = GIT_BRANCH_STATUS[:no_tracking]
          @branch_message = "未追踪远程分支\"origin/#{branch}\""
        else
          # 无默认远程分支
          @branch_status = GIT_BRANCH_STATUS[:no_remote]
          @branch_message = "对应远程分支不存在"
        end
      end

      # 解析状态
      #
      # @param list [Array<String>] 状态行数组（通过git status -s输出）
      #
      # @return [GIT_REPO_STATUS，String，GIT_REPO_STATUS_DIRTY_ZONE] 状态；描述信息；脏区域
      #
      def parse_change(list)
        index_message, work_tree_message, conflict_message, special_message = [], [], [], []
        list.each { |line|
          index_status = line[0]
          work_tree_status = line[1]
          combined_status = index_status + work_tree_status
          changed_file = line[3..-1]

          change_message = convert_file_status(STATUS_TYPE[:conflicts], combined_status)
          if !change_message.nil?
            conflict_message.push(change_message + changed_file)
          end

          change_message = convert_file_status(STATUS_TYPE[:special], combined_status)
          if !change_message.nil?
            special_message.push(change_message + changed_file)
          end

          change_message = convert_file_status(STATUS_TYPE[:normal], index_status)
          if !change_message.nil?
            index_message.push(change_message + changed_file)
          end

          change_message = convert_file_status(STATUS_TYPE[:normal], work_tree_status)
          if !change_message.nil?
            work_tree_message.push(change_message + changed_file)
          end
        }

        output = []
        dirty_zone = 0
        if index_message.length > 0
          output.push(['暂存区', index_message])
          dirty_zone |= GIT_REPO_STATUS_DIRTY_ZONE[:index]
        end

        if work_tree_message.length > 0
          output.push(['工作区', work_tree_message])
          dirty_zone |= GIT_REPO_STATUS_DIRTY_ZONE[:work_tree]
        end

        if conflict_message.length > 0
          output.push(['冲突[我方|对方]', conflict_message])
          dirty_zone |= GIT_REPO_STATUS_DIRTY_ZONE[:work_tree]
        end

        if special_message.length > 0
          output.push(['特殊', special_message])
          dirty_zone |= GIT_REPO_STATUS_DIRTY_ZONE[:special]
        end

        status = GIT_REPO_STATUS[:dirty]
        return status, output, dirty_zone
      end

      # 转化文件状态
      #
      # @param type [STATUS_TYPE] 状态类型
      #
      # @param status [String] 文件状态
      #
      # @return [FILE_STATUS_MESSAGE] 文件状态描述
      #
      def convert_file_status(type, status)
        if type == STATUS_TYPE[:normal]
          return FILE_STATUS_MESSAGE[status.to_s] if FILE_STATUS.values.include?(status)
        elsif type == STATUS_TYPE[:conflicts]
          return FILE_STATUS_MESSAGE[status.to_s] if FILE_STATUS_CONFLICT.values.include?(status)
        elsif type == STATUS_TYPE[:special]
          return FILE_STATUS_MESSAGE[status.to_s] if FILE_STATUS_SPECIAL.values.include?(status)
        end
        return nil
      end
    end
  end
end
