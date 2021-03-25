#coding=utf-8

module MGit
  # 计时器，用于统计指令执行耗时
  class Timer

    @@time_stamp = {}
    @@duration = {}
    @@lock = Mutex.new

    class << self

      # 开始计时
      #
      # @param repo_name [String] 仓库名
      #
      # @param use_lock [Boolean] default: false 是否加锁
      #
      def start(repo_name, use_lock:false)
        return if repo_name.nil?
        mutex_exec(use_lock) {
          @@time_stamp[repo_name] = Time.new if @@time_stamp[repo_name].nil?
          @@duration[repo_name] = 0 if @@duration[repo_name].nil?
        }
      end

      # 停止计时
      #
      # @param repo_name [String] 仓库名
      #
      # @param use_lock [Boolean] default: false 是否加锁
      #
      def stop(repo_name, use_lock:false)
        return if repo_name.nil?
        mutex_exec(use_lock) {
          if !@@time_stamp[repo_name].nil? && !@@duration[repo_name].nil?
            @@duration[repo_name] += Time.new.to_f - @@time_stamp[repo_name].to_f
            @@time_stamp[repo_name] = nil
          end
        }
      end

      # 显示最耗时仓库
      #
      # @param threshold [Type] default: 5 耗时提示阈值，时间超过该阈值则将仓库纳入提醒集合
      #
      def show_time_consuming_repos(threshold:5)
        repos = []
        @@duration.sort_by { |repo_name,seconds| seconds }.reverse.first(5).each { |info|
          repo_name = info.first
          seconds = info.last
          repos.push("[#{seconds.round(2)}s]#{repo_name}") if seconds > threshold
        }
        Output.puts_remind_block(repos, "以上为最耗时且耗时超过#{threshold}s的仓库,请自行关注影响速度的原因。") if repos.length > 0
      end

      # 多线程执行保护
      #
      # @param use_lock [Boolean] 执行是否加锁
      #
      def mutex_exec(use_lock)
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
end
