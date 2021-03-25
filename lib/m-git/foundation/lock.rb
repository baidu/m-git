
module MGit
  class Lock
    class << self

      # @!scope 互斥执行锁
      # @example
      # mutex_exec do
      #   exec..
      # end
      def mutex_exec
        @mutex = Mutex.new if @mutex.nil?
        @mutex.lock
        yield if block_given?
        @mutex.unlock
      end

      # @!scope 互斥显示锁
      # @example
      # mutex_puts do
      #   exec..
      # end
      def mutex_puts
        @mutex_puts = Mutex.new if @mutex_puts.nil?
        @mutex_puts.lock
        yield if block_given?
        @mutex_puts.unlock
      end

    end
  end
end
