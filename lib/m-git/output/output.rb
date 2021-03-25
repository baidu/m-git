#coding=utf-8

require 'm-git/foundation'

module MGit
  module Output
    class << self

# --- 简单输出 ---

      def puts_cancel_message
        puts_fail_message("执行取消！")
      end

      def puts_succeed_cmd(cmd)
        puts_success_message("指令[ mgit #{cmd} ]执行成功！")
      end

      def puts_start_cmd
        puts_processing_message("开始执行...")
      end

      def puts_fail_cmd(cmd)
        puts_fail_message("指令[ mgit #{cmd} ]执行失败！")
      end

      def puts_nothing_to_do_cmd
        puts_remind_message("没有仓库需要执行指令！")
      end

      def puts_success_message(str)
        MGit::Loger.info(str.strip)
        puts success_message(str)
      end

      def puts_remind_message(str)
        MGit::Loger.info(str)
        puts remind_message(str)
      end

      def puts_terminate_message(str, title:nil)
        MGit::Loger.error("#{title}: #{str}")
        puts terminate_message(str, title:title)
      end

      def puts_fail_message(str)
        MGit::Loger.error(str)
        puts fail_message(str)
      end

      def puts_processing_message(str)
        MGit::Loger.info(str)
        puts processing_message(str)
      end

      def puts_fail_block(list, bottom_summary)
        puts generate_fail_block(list, bottom_summary)
      end

      def puts_remind_block(list, bottom_summary)
        puts generate_remind_block(list, bottom_summary)
      end

      def puts_processing_block(list, bottom_summary)
        puts generate_processing_block(list, bottom_summary)
      end

      def puts_fail_combined_block(list_array, bottom_summary, title:nil)
        puts generate_fail_combined_block(list_array, bottom_summary, title:title)
      end

      def puts_in_pager(output)
        begin
          pager = TTY::Pager.new
          pager.page(output)
        rescue => _
        end
      end

# --- 交互式输出 ---

      def continue_with_user_remind?(msg)
        puts blue_message("[?] #{msg} Y/n")
        MGit::DurationRecorder.pause
        input = nil
        loop do
          input = STDIN.gets.chomp.downcase
          if input == 'y' || input == 'yes' || input == 'n' || input == 'no'
            break
          end
          puts blue_message("[?] 输入不合法,#{msg} Y/n")
        end
        MGit::DurationRecorder.resume
        return input == 'y' || input == 'yes'
      end

      def continue_with_interact_repos?(repos, msg)
        output = generate_table(repos, separator:'|') + "\n"
        output += blue_message("[?] #{msg} Y/n")
        puts output
        MGit::DurationRecorder.pause
        input = nil
        loop do
          input = STDIN.gets.chomp.downcase
          if input == 'y' || input == 'yes' || input == 'n' || input == 'no'
            break
          end
          puts blue_message("[?] 输入不合法,#{msg} Y/n")
        end
        MGit::DurationRecorder.resume
        return input == 'y' || input == 'yes'
      end

      def continue_with_combined_interact_repos?(repos_array, msg, title:nil)
        output = generate_table_combination(repos_array, title:title, separator:'|') + "\n"
        output += blue_message("[?] #{msg} Y/n")
        puts output
        MGit::DurationRecorder.pause
        input = nil
        loop do
          input = STDIN.gets.chomp.downcase
          if input == 'y' || input == 'yes' || input == 'n' || input == 'no'
            break
          end
          puts blue_message("[?] 输入不合法,#{msg} Y/n")
        end
        MGit::DurationRecorder.resume
        return input == 'y' || input == 'yes'
      end

# 显示一组复合表格并显示多选项操作
#
# @param list_array [Array<Array>] 包含表格内容的数组，其中每个元素为数组，表示一张表格内容，list_array内容为：【【title1, list1】,【title2, list2】...】, title<String>为标题，list<Array>为单张表格元素数组，所有内容会被渲染为多张表格然后合并为一张
#
# @param msg [string] 交互消息
#
# @param selection [Array] 选型数组，如:【'a: 跳过并继续', 'b: 强制执行', 'c: 终止'】
#
      def interact_with_multi_selection_combined_repos(list_array, msg, selection)
        puts generate_table_combination(list_array, separator:'|')
        puts blue_message("[?] #{msg}，请选择操作：\n#{selection.join("\n")}")
        MGit::DurationRecorder.pause
        input = STDIN.gets.chomp
        MGit::DurationRecorder.resume
        yield(input) if block_given?
      end

# --- 特定消息生成器 ---

      def processing_message(str)
        return yellow_message("[~] #{str}")
      end

      def remind_message(str)
        return blue_message("[!] #{str}")
      end

      def success_message(str)
        return green_message("[✔] #{str}")
      end

      def fail_message(str)
        return red_message("[✘] #{str}")
      end

      def terminate_message(str, title:nil)
        header = "执行终止"
        header = title if !title.nil?
        return red_message("[✘✘✘ #{header} ✘✘✘] #{str}")
      end

# --- 有色输出生成器 ---

# 绿色提示信息
      def green_message(str)
        return "\033[32m#{str}\033[0m"
      end

# 青色提示信息
      def blue_message(str)
        return "\033[36m#{str}\033[0m"
      end

# 紫红色提示信息
      def red_message(str)
        return "\033[31m#{str}\033[0m"
      end

# 黄色提示信息
      def yellow_message(str)
        return "\033[33m#{str}\033[0m"
      end

      def info_title(str)
        return "\033[4m#{str}\033[0m"
      end

# --- 格式化输出生成器 ---

      def generate_fail_combined_block(list_array, bottom_summary, title:nil)
        return '' if list_array.nil? || list_array.length == 0
        output = generate_table_combination(list_array, title: title, separator:'|') + "\n"
        output += fail_message(bottom_summary)
        return output
      end

      def generate_remind_block(list, bottom_summary)
        msg = generate_block(list, remind_message(bottom_summary))
        MGit::Loger.info(bottom_summary)
        return msg
      end

      def generate_fail_block(list, bottom_summary)
        msg = generate_block(list, fail_message(bottom_summary))
        MGit::Loger.info(bottom_summary)
        return msg
      end

      def generate_processing_block(list, bottom_summary)
        msg = generate_block(list, processing_message(bottom_summary))
        MGit::Loger.info(bottom_summary)
        return msg
      end

      def generate_block(list, bottom_summary)
        return '' if list.nil? || list.length == 0
        output = generate_table(list, separator:'|') + "\n"
        output += bottom_summary
        MGit::Loger.info(list)
        return output
      end

      def generate_title_block(title, has_separator:true)
        title = "--- #{title} ---"
        separator = ''
        separator = "\n" + '=' * string_length_by_ascii(title) if has_separator
        output = blue_message(title + separator) + "\n"
        output += yield(output)
        return output
      end

# 生成合成表格(将多个表格融合为一个)
#
# @param list_array [Array<Array>] 包含表格内容的数组，其中每个元素为数组，表示一张表格内容，list_array内容为：【【title1, list1】,【title2, list2】...】, title<String>为标题，list<Array>为单张表格元素数组，所有内容会被渲染为多张表格然后合并为一张
#
# @param title [String] default: nil 表格标题
#
# @param separator [String] default: '' 表格内元素分割线
#
# @return [String] 生成的合成表格
#
      def generate_table_combination(list_array, title:nil, separator:'')
        table_width = -1
        head_separator = "| "
        middle_separator = " #{separator} "
        tail_separator = " |"
        head_tail_padding = head_separator.length + tail_separator.length

        list_array.each { |list|
          items = list.last
          max_table_width, _, _ = calculate_table_info(items, head_separator, middle_separator, tail_separator, title:list.first)
          table_width = max_table_width if !max_table_width.nil? && max_table_width > table_width
        }

        output = ''
        if !title.nil? && table_width > 0

          title_length = string_length_by_ascii(title)
          table_width = title_length + head_tail_padding if table_width < title_length + head_tail_padding

          space = secure(table_width - head_tail_padding - title_length) / 2
          head_line = head_separator + ' ' * space +  title
          head_line = head_line + ' ' * secure(table_width - string_length_by_ascii(head_line) - tail_separator.length) + tail_separator + "\n"

          output += '-' * table_width + "\n"
          output += head_line
        end

        list_array.each_with_index { |list, idx|
          sub_title = list.first if !list.first.nil? && list.first != ''
          output += generate_table(list.last, title:sub_title, separator:separator, fixed_width:table_width, hide_footer_line:idx != list_array.length - 1)
        }
        return output
      end

# 生成表格
#
# @param list [Array] 包含表格中显示内容
#
# @param title [String] default: nil 表格标题
#
# @param separator [String] default: '' 表格内部分割线
#
# @param fixed_width [Number] default: -1 可指定表格宽度，若指定宽度大于计算所得最大宽度，则使用该指定宽度
#
# @param hide_footer_line [Boolean] default: false 隐藏底部分割线
#
# @return [String] 已生成的表格字符串
#
      def generate_table(list, title:nil, separator:'', fixed_width:-1, hide_footer_line:false)
        return '' if list.nil? || list.length == 0

        output = ''
        head_separator = "| "
        middle_separator = " #{separator} "
        tail_separator = " |"
        head_tail_padding = head_separator.length + tail_separator.length

        max_table_width, column, max_meta_display_length_by_ascii = calculate_table_info(list, head_separator, middle_separator, tail_separator, title:title, fixed_width:fixed_width)

        if !max_table_width.nil? && !column.nil? && !max_meta_display_length_by_ascii.nil?
          if !title.nil?
            title_length = string_length_by_ascii(title)
            title = head_separator + title + ' ' * secure(max_table_width - title_length - head_tail_padding) + tail_separator

            max_table_width = title_length + head_tail_padding if max_table_width < title_length + head_tail_padding
            output += '-' * max_table_width + "\n"
            output += title + "\n"

            # 处理标题下的分割线
            output += head_separator + '-' * title_length + ' ' * secure(max_table_width - head_tail_padding - title_length) + tail_separator + "\n"
          else
            output += '-' * max_table_width + "\n"
          end

          list.each_slice(column).to_a.each { |row|
            line = head_separator
            row.each_with_index { |item, idx|
              # 最大显示宽度由纯ascii字符个数度量，而输出时中文占2个ascii字符宽度
              # ljust方法以字符做计算，一个汉字会被认为是一个字符，但占了2单位宽度，需要把显示宽度根据汉字个数做压缩，如:
              # 最长显示字符（纯ascii字符）：'abcdef1234', 字符长度10，占10个ascii字符显示宽度
              # 需要输出字符串：'[删除]abc'，字符长度7，但有2个汉字，占9个ascii字符显示宽度
              # 因此，ljust接受宽度字符个数：10 - 2 = 8
              # 即对于'[删除]abc'这样的字符串，8个字符对应的ascii字符显示宽度（'[删除]abc ', 注意8个字符宽度此时有一个空格）和'abcdef1234'显示宽度等长
              line += item.ljust(max_meta_display_length_by_char(item, max_meta_display_length_by_ascii))
              line += middle_separator if idx != row.length - 1
            }
            last_line_space = ' ' * secure(max_table_width - string_length_by_ascii(line) - tail_separator.length)
            line += last_line_space + tail_separator
            output += line + "\n"
          }
          output += '-' * max_table_width if !hide_footer_line
        else
          if list.length > 1
            output = list.join("\n")
          else
            output = list.first + "\n"
          end
        end

        return output
      end

# 计算表格信息
#
# @param list [Array] 包含表格中显示内容
#
# @param head_separator [String] 表格头部分割线
#
# @param middle_separator [String] 表格中部分割线
#
# @param tail_separator [String] 表格尾部分割线
#
# @param fixed_width [Number] default: -1 可指定表格宽度，若指定宽度大于计算所得最大宽度，则使用该指定宽度
#
# @return [Objtct...] 返回表格最大宽度，表格列数，表格中一个项目显示的最大长度
#
      def calculate_table_info(list, head_separator, middle_separator, tail_separator, title:nil, fixed_width:-1)
        return nil if list.nil? || list.length == 0

        head_tail_padding = head_separator.length + tail_separator.length

        max_meta_display_length_by_ascii = -1
        list.each { |item|
          display_length = string_length_by_ascii(item)
          if max_meta_display_length_by_ascii < display_length
            max_meta_display_length_by_ascii = display_length
          end
        }

        # 终端宽度。
        # -1：减去最后一行"\n"
        screen_width = `tput cols`.to_i - 1
        if screen_width > 0 && screen_width > max_meta_display_length_by_ascii + head_tail_padding
          # 定义：
          # n：列数
          # a：单个item最大长度
          # b：分隔字符长度
          # l：表格宽度减去前后padding的长度
          # 如：| [abc]def | [def]abcd | [zz]asdf |
          # 有：  |<------------ l ------------>|
          #                 |<- a -->|
          # n=3，a=9，b=3(' | '.length == 3)，l=31

          # 计算l
          raw_length = screen_width - head_tail_padding

          # 计算列数：n * a + (n - 1) * b = l => n = (l + b) / (a + b)
          column = (raw_length + middle_separator.length) / (max_meta_display_length_by_ascii + middle_separator.length)

          # 如果计算得到的列数小于item个数，那么取item个数为最大列数
          column = list.length if column > list.length

          # 计算一个item的平均长度“al”，由
          # 1. n * a + (n - 1) * b = l
          # 2. al = l / n
          # => al = (n * (a + b) - b) / n
          average_length = (column * (max_meta_display_length_by_ascii + middle_separator.length) - middle_separator.length) / column.to_f

          # 表格最大宽度为：n * al + head_tail_padding
          max_table_width = (column * average_length + head_tail_padding).ceil

          # 如果title最宽，则使用title宽度
          if !title.nil? && title.is_a?(String)
            title_length = string_length_by_ascii(head_separator + title + tail_separator)
            max_table_width = title_length if max_table_width < title_length && title_length < screen_width
          end

          # 如果指定了一个合理的宽度，则使用该宽度
          max_table_width = fixed_width if max_table_width < fixed_width && fixed_width <= screen_width

          return max_table_width, column, max_meta_display_length_by_ascii
        else
          return nil
        end
      end

# 输出时中文占2个字符宽度，根据字符串中的汉字个数重新计算字符串长度（以纯ascii字符作度量）
      def string_length_by_ascii(str)
        chinese_chars = str.scan(/\p{Han}/)
        length = str.length + chinese_chars.length
        return length
      end

# 输出时中文占2个字符宽度，根据字符串中的汉字个数重新计算最大显示字符长度（以包括汉字在内的字符作度量）
      def max_meta_display_length_by_char(str, max_meta_display_length_by_ascii)
        chinese_chars = str.scan(/\p{Han}/)
        return max_meta_display_length_by_ascii - chinese_chars.length
      end

# 保证数字大于0
      def secure(num)
        return num > 0 ? num : 0
      end

# --- 进度条 ---

      def update_progress(totaltasks, finishtasks)
        totalmark = 30
        progress = totaltasks > 0 ? (finishtasks * 100.0 / totaltasks).round : 100
        progress_str = ''
        pre_num = (totalmark / 100.0 * progress).round
        progress_str += '#' * pre_num
        progress_str += ' ' * (totalmark - pre_num)
        bar = "\r[#{progress_str}] #{progress}%"
        bar += "\n" if progress == 100
        print bar
      end
    end
  end
end