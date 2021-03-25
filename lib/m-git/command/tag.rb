#coding=utf-8

module MGit

  # @!scope 类似 git tag
  #
  class Tag < BaseCommand

    def execute(argv)
      Workspace.check_branch_consistency

      Output.puts_start_cmd

      exec_repos = all_repos + locked_repos

      if argv.git_opts.empty?
        _, error_repos = Workspace.execute_git_cmd_with_repos(argv.cmd, argv.git_opts, exec_repos)
        Output.puts_succeed_cmd(argv.absolute_cmd) if error_repos.length == 0
        return
      end

      error_repos = {}
      no_tag_repos = []
      exec_repos.each { |repo|
        success, output = repo.execute_git_cmd(argv.cmd, argv.git_opts)
        if success
          tags = output.split("\n")
          if tags.length > 0
            puts Output.generate_title_block(repo.name) {
              Output.generate_table(tags, separator:"")
            }
          else
            no_tag_repos.push(repo.name)
          end
        else
          error_repos[repo.name] = output
        end
      }

      if no_tag_repos.length > 0
        puts "\n"
        Output.puts_remind_block(no_tag_repos, "以上仓库尚未创建tag！")
      end

      if error_repos.length > 0
        Workspace.show_error(error_repos)
      else
        Output.puts_succeed_cmd(argv.absolute_cmd)
      end

    end

    def enable_repo_selection
      true
    end

    def self.description
      "增删查或验证标签。增加标签示例：mgit tag -a 'v0.0.1' -m 'Tag description message'"
    end

    def self.usage
      "mgit tag [<git-tag-option>] [(--mrepo|--el-mrepo) <repo>...] [--help]"
    end

  end

end
