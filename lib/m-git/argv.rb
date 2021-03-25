#coding=utf-8

module MGit

  # 参数处理类
  class ARGV

    require 'm-git/argv/opt'
    require 'm-git/argv/opt_list'
    require 'm-git/argv/parser'

    # 指令名，如："mgit checkout -b branch_name"的"checkout"
    attr_reader :cmd

    # 所有参数，如："mgit checkout -b branch_name"的"checkout -b branch_name"
    attr_reader :pure_opts

    # 完整指令，如："mgit checkout -b branch_name"
    attr_reader :absolute_cmd

    # 本次传入的mgit指令中自定义的部分，如："mgit checkout -b branch_name --mrepo boxapp BBAAccount --command test"的"[[--mrepo boxapp BBAAccount],[--command test]]"
    attr_reader :raw_opts

    # 本次传入的mgit指令中git透传的部分，如："mgit checkout -b branch_name --mrepo boxapp BBAAccount"的"[[-b branch_name]]"
    # has define method git_opts

    # 所有已注册的参数列表
    attr_reader :opt_list

    def initialize(cmd, pure_opts, absolute_cmd, raw_opts)
      @cmd = cmd
      @pure_opts = pure_opts
      @absolute_cmd = absolute_cmd
      @raw_opts = raw_opts
      @git_opts = []
    end

    def register_opts(opts)
      return if opts.nil?
      @opt_list = OptList.new(opts)
    end

    # 注册解析指令
    def resolve!
      @raw_opts.each { |raw_opt|
        next if @opt_list.did_register_opt?(raw_opt.first)
        @git_opts.push(raw_opt)
      }

      @raw_opts -= @git_opts

      __resolve_git_opts
      __resolve_raw_opts
    end

    # 更新指令值
    # @!attribute [Array / String / true / false] value
    #
    def update_opt(key, value, priority:nil, info:nil)
      return unless @opt_list.did_register_opt?(key)
      opt = @opt_list.registered_opt(key)
      case opt.value_type
      when Array
        opt.value = Array(value)
      when String
        opt.value = value.is_a?(Array) ? value.first.to_s : value.to_s
      else # boolean
        opt.value = value
      end

      opt.priority = priority if !priority.nil?
      opt.info = info if info.is_a?(String)
    end

    # 获取某个option
    def opt(key)
      @opt_list.opt(key)
    end

    # 获取某个option的描述信息
    def info(key)
      return '' unless @opt_list.did_register_opt?(key)
      @opt_list.registered_opt(key)&.info
    end

    # 获取原生git指令（非自定义的指令）
    #
    # @param raw [Boolean] default: true，true：用空格拼接成一个字符串返回。false：直接返回数组，如‘-k k1 k2’ -> 【'-k','k1','k2'】
    #
    # @return [Type] description_of_returned_object
    #
    def git_opts(raw: true)
      return @git_opts unless raw
      opts = []
      @git_opts.each { |e_arr|
        opts += e_arr
      }
      opts.join(' ')
    end

    # 遍历本次调用中传入过值（或有默认值）的选项，未传入值且无默认值则不遍历
    def enumerate_valid_opts
      @opt_list.opts_ordered_by_priority.each { |opt|
        next unless @opt_list.did_set_opt?(opt.key)
        yield(opt) if block_given?
      }
    end

    # 判断一个字符串是否是option（以'--'或'-'开头）
    def is_option?(opt_str)
      (opt_str =~ /-/) == 0 || (opt_str =~ /--/) == 0
    end

    # 输出本次指令的具体值信息，调试时使用
    def show_detail
      @opt_list.opts.each { |opt|
        puts '======='
        puts "key:#{opt.key}"
        puts "value:#{opt.value}"
        puts "info:#{opt.info}"
        puts "\n"
      }
    end

    # 输出参数说明信息
    def show_info
      @opt_list.opts.each { |opt|
        short_key = "#{opt.short_key}, " if !opt.short_key.nil?
        puts "\n"
        puts Output.blue_message("[#{short_key}#{opt.key}]")
        puts "#{opt.info}"
      }
    end

    private

    def __resolve_git_opts
      # 统一将值用双引号括起来，避免空格和特殊字符等引起错误
      @git_opts.each { |e_arr|
        next unless is_option?(e_arr.first)
        e_arr.map!.with_index { |e, i|
          # 如果是 -- / - 开始的option，则增加"" 避免特殊字符的错误，eg： --yoo=ajsdaf  => --yoo="ajsdaf"
          # 如果是 repo1 repo2 这样的option，则不作处理，eg： yoo ajsdaf => yoo ajsdaf
          e = "\"#{e}\"" if !is_option?(e) && i > 0
          e
        }
      }
    end

    def __resolve_raw_opts
      @raw_opts.each { |raw_opt|
        key = raw_opt.first
        opt = @opt_list.registered_opt(key)

        case opt.value_type
        when :boolean
          raise "参数#{key}格式错误，禁止传入参数值！(用法：#{key})" if raw_opt.count != 1
          opt.value = true
        when :string
          raise "参数#{key}格式错误，只能传入一个参数值！(用法：#{key} xxx)" if raw_opt.count != 2
          opt.value = raw_opt.last.to_s
        when :array
          raise "参数#{key}格式错误，至少传入一个参数值！(用法：#{key} xxx xxx ...)" if raw_opt.count < 2
          opt.value = raw_opt[1..-1]
        end
      }
    end
  end

end
