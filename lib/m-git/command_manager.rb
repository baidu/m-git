
module MGit
  class CommandManager
    class << self
      # cmd generate
      #
      def commands
        @commands ||= {}
      end

      def register_command(cmd, cls)
        commands[cmd] = cls
      end

      def [](cmd)
        class_with_command(cmd)
      end

      def class_with_command(cmd)
        commands[cmd]
      end
    end
  end
end
