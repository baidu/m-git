
module MGit
  # Git interact message parse with git-server
  #
  class GitMessageParser

    def initialize(url)
      @url = url
    end

    # @return [String] error message
    # @return [nil] none error
    #
    def parse_fetch_msg(input)
      parse_pull_msg(input)
    end

    # @return [String] error message
    # @return [nil] none error
    #
    def parse_pull_msg(input)
      __default_parse_msg(input)
    end

    # @return [String] error message
    # @return [nil] none error
    #
    def parse_push_msg(input)
      __default_parse_msg(input)
    end

    # @return [String] codereview的url地址
    # 默认无解析
    def parse_code_review_url(input)
      nil
    end

    def __default_parse_msg(msg)
      return if msg.nil? || msg.empty?

      key_word = 'error:'
      error_line = msg.split("\n").find {|line|
        # 解析 "error: failed to push some refs..."
        line.include?(key_word)
      }
      msg if error_line
    end
  end

end
