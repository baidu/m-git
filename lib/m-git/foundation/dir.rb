
class Dir

  # 检查传入路径是不是git仓库
  #
  # @param path [String] 仓库路径
  #
  def self.is_git_repo?(path)
    return false unless File.directory?(path)
    git_dir = File.join(path, '.git')
    File.directory?(git_dir)
  end

  def self.is_in_git_repo?(path)
    check_path = path
    result = is_git_repo?(check_path)
    while !result
      check_path = File.dirname(check_path)
      break if check_path == '/'
      result = is_git_repo?(check_path)
    end
    result
  end

end