#coding=utf-8

module MGit

  # @!scope 查询多仓库的日志
  #
  class Log < BaseCommand

    OPT_LIST = {
      :number    =>  '--number',
      :number_s  =>  '-n'
    }.freeze

    def options
      return [
          ARGV::Opt.new(OPT_LIST[:number], short_key:OPT_LIST[:number_s], default:500, info:"指定需要显示的提交log个数，默认500。", type: :string)
      ].concat(super)
    end

    def revise_option_value(opt)
      opt.value = Integer(opt.value) if opt.key == OPT_LIST[:number]
    end

    def execute(argv)
      repo_name = parse_repo_name(argv)
      repo = all_repos.find { |e| e.name.downcase == repo_name.downcase }
      number = argv.opt(OPT_LIST[:number]).value
      if repo.nil?
        Output.puts_fail_message("未找到与输入仓库名\"#{repo_name}\"匹配的仓库，请重试！") && return
        return
      end
      # print(Output.processing_message("正在提取#{repo.name}最新的#{number}条log信息..."))
      success, output = repo.execute_git_cmd(argv.cmd, "-n #{number}")
      if success
        if output.length > 0
          Output.puts_in_pager(output.gsub(/commit.*/) { |s| Output.yellow_message(s) })
          # print("\r")
        else
          Output.puts_remind_message("无提交记录")
        end
      else
        Output.puts_fail_message("执行失败：#{output}")
      end
    end

    def parse_repo_name(argv)
      return nil if argv.git_opts.nil?
      repo = argv.git_opts.split(' ')
      extra_opts = repo.select { |e| argv.is_option?(e) }
      Foundation.help!("输入非法参数：#{extra_opts.join('，')}。请通过\"mgit #{argv.cmd} --help\"查看用法。") if extra_opts.length > 0
      Foundation.help!("未输入查询仓库名！请使用这种形式查询：mgit log some_repo") if repo.length == 0
      Foundation.help!("仅允许查询一个仓库！") if repo.length > 1
      repo.first
    end

    def is_integer?(string)
      true if Integer(string) rescue false
    end

    def enable_short_basic_option
      true
    end

    def self.description
      "输出指定(单个)仓库的提交历史。"
    end

    def self.usage
      "mgit log <repo> [-n] [-h]"
    end
  end

end
