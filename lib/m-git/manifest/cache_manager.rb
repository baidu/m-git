
module MGit
  class Manifest
    class CacheManager

      attr_reader :path
      attr_reader :hash_sha1
      attr_reader :hash_data

      def load_path(cache_path)
        return unless File.exist?(cache_path)
        begin
          cache = JSON.parse(File.read(cache_path))
        rescue => _
          Output.puts_fail_message("配置文件缓存解析失败！将根据原配置文件进行仓库配置。")
        end

        @path = cache_path
        @hash_sha1 = cache[Constants::CONFIG_CACHE_KEY[:hash]]
        @hash_data = cache[Constants::CONFIG_CACHE_KEY[:cache]]
      end

      # 缓存配置文件
      #
      # @param cache_path [string] 配置文件目录
      #
      # @param hash_sha1 [String] 配置哈希字符串
      #
      # @param hash_data [Hash] 配置字典
      #
      def self.save_to_cache(cache_path, hash_sha1, hash_data)
        FileUtils.mkdir_p(File.dirname(cache_path))
        File.open(cache_path, 'w') do |file|
          file.write({
                         Constants::CONFIG_CACHE_KEY[:hash]   => hash_sha1,
                         Constants::CONFIG_CACHE_KEY[:cache]  => hash_data
                     }.to_json)
        end
      end


    end
  end
end
