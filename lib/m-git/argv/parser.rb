
module MGit
  class ARGV
    module Parser

      # @param [Array] argv
      #
      # @return [String, Array, Array]
      # 返回cmd 和 参数列表
      # # 将参数初步分解，便于后续处理
      # 如：argv = [command zzzz -u sdfsd sdf --mmmm yoo ssss qqq --test asdfa asd ad f --xxx asd as dfa --yoo="ajsdaf" --ppp -abc]
      # 分解为：command, [zzzz], [[-u, sdfsd, sdf], [--mmmm, yoo, ssss, qqq], [--test, asdfa, asd, ad, f], [--xxx, asd, as, dfa], [--yoo, "ajsdaf"], [--ppp], [-a], [-b], [-c]]
      #
      # 初步解析参数
      def self.parse(argv)
        absolute_cmd = argv.join(' ')
        cmd = argv.shift
        pure_opts = argv.join(' ')

        # 将参数初步分解，便于后续处理
        # 如：zzzz -u sdfsd sdf --mmmm yoo ssss qqq --test asdfa asd ad f --xxx asd as dfa --yoo="ajsdaf" --ppp -abc
        # 分解为：[[zzzz], [-u, sdfsd, sdf], [--mmmm, yoo, ssss, qqq], [--test, asdfa, asd, ad, f], [--xxx, asd, as, dfa], [--yoo, "ajsdaf"], [--ppp], [-a], [-b], [-c]]
        temp = []
        raw_opts = []
        argv.each_with_index { |e, idx|

          Foundation.help!("参数\"#{e}\"格式错误，请使用格式如：\"--long\"或\"-s\"") if (e =~ /---/) == 0

          # 检查是否是带'--'或'-'的参数
          if (e =~ /-/) == 0
            # 回收缓存
            raw_opts.push(temp) if temp.length != 0
            # 清空临时缓存
            temp = []

            # 如果是合并的短指令，如'-al = -a + -l'，则分拆后直接装入raw_opts数组
            # 因为只有不需要传入值的短参数才能合并，因此不利用临时缓存读取后续参数值
            if e.length > 2 && (e =~ /--/).nil? && !e.include?('=')
              e.split('')[1..-1].each { |s|
                raw_opts.push(["-#{s}"])
              }
              next
            end

            # 处理带‘=’的传值参数
            loc = (e =~ /=/)
            if loc
              temp.unshift(e[(loc + 1)..-1])
              temp.unshift(e[0..loc - 1])
            elsif e.length != 0
              temp.push(e)
            end

          elsif e.length != 0
            temp.push(e)
          end

          if idx == argv.length - 1
            raw_opts.push(temp)
          end
        }
        ARGV.new(cmd, pure_opts, absolute_cmd, raw_opts)
      end
    end
  end
end
