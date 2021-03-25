#coding=utf-8

module MGit

  # 计时器
  #
  class DurationRecorder

    DEFAULT_DURATION_KEY = 'default_duration_key'

    module Status
      # 停止态
      IDLE = 0
      # 暂停态
      PAUSE = 1
      # 计时中
      RUNNING = 2
    end

    include Status

    @@status = {}
    @@duration = {}
    @@time_stamp = {}
    @@lock = Mutex.new

    def self.start(duration_key:DEFAULT_DURATION_KEY, use_lock:false)
      mutex_exec(use_lock) {
        status = IDLE if @@status[duration_key].nil?
        if status == IDLE
          @@duration[duration_key] = 0.0
          @@time_stamp[duration_key] = Time.new.to_f
          @@status[duration_key] = RUNNING
        else
          puts '需要停止计时后重新开始计时'
        end
      }
    end

    def self.pause(duration_key:DEFAULT_DURATION_KEY, use_lock:false)
      mutex_exec(use_lock) {
        if @@status[duration_key] == RUNNING
          current = Time.new.to_f
          @@duration[duration_key] += (current - @@time_stamp[duration_key])
          @@time_stamp.delete(duration_key)
          @@status[duration_key] = PAUSE
        end
      }
    end

    def self.resume(duration_key:DEFAULT_DURATION_KEY, use_lock:false)
      mutex_exec(use_lock) {
        if @@status[duration_key] == PAUSE
          @@time_stamp[duration_key] = Time.new.to_f
          @@status[duration_key] = RUNNING
        end
      }
    end

    def self.end(duration_key:DEFAULT_DURATION_KEY, use_lock:false)
      mutex_exec(use_lock) {
        if @@status[duration_key] != IDLE
          current = Time.new.to_f
          @@duration[duration_key] += (current - @@time_stamp[duration_key])
          @@time_stamp.delete(duration_key)
          @@status[duration_key] = IDLE
          return @@duration[duration_key]
        else
          puts '没有需要停止的计时'
        end
      }
    end

    private

    # 多线程执行保护
    #
    # @param use_lock [Boolean] 执行是否加锁
    #
    def self.mutex_exec(use_lock)
      if use_lock
        @@lock.lock
        yield if block_given?
        @@lock.unlock
      else
        yield if block_given?
      end
    end

  end

end
