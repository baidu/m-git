#coding=utf-8

module MGit

  class Repo
    class SyncHelper

      class << self

        # 同步新仓库
        #
        # @param repo [MGigClass::Repo] Repo对象
        #
        # @param light_repo [Manifest::LightRepo] LightRepo对象
        #
        # @param link_git [Boolean] 下载新仓库的时候是否托管.git实体并在工作区创建其软链接
        #
        # @return [String, Repo] String：执行结果，成功返回nil，错误返回错误信息，Repo：成功返回nil，错误返回新生成的repo对象
        #
        def sync_new_repo(light_repo, root, link_git:true)
          def __sync_local_repo(light_repo, root, link_git:true)
            output, repo = nil, nil
            git_entity = File.join(light_repo.git_store_dir(root), '.git')
            # 先git clone -- local_git_repo，再软链git_entity，再checkout分支
            clone_url = "git clone -- #{git_entity} #{light_repo.abs_dest(root)}"
            Utils.execute_shell_cmd(clone_url) { |stdout, stderr, status|
              if status.success?
                repo = Repo.generate_strictly(root, light_repo)
                repo_git = File.join(repo.path, '.git')
                manage_git = MGitConfig.query_with_key(root, :managegit)
                if manage_git && link_git
                  FileUtils.rm_rf(repo_git)
                  Utils.link(git_entity, repo_git)
                end
                msg = ''
                # 如果从本地clone的话，remote url是指向本地的，需要更新
                error_message = sync_remote_url(repo, light_repo)
                msg += error_message + "\n" if !error_message.nil?
                # 本地仓库可能太旧，执行pull更新代码和新分支
                success, error_message = repo.execute_git_cmd('fetch', '')
                if !success && !error_message.nil? && error_message.length > 0
                  msg += "由于存在本地仓库源，已从本地克隆，但代码更新失败，请自行fetch最新代码。原因：\n" + error_message + "\n"
                end

                # 同步锁定点
                error_message = sync_lock_point(repo, light_repo)
                msg += error_message if !error_message.nil?

                output = msg.length > 0 ? msg : nil
              else
                output = "同步仓库\"#{light_repo.name}\"时clone失败，如果远程仓库不存在，请在配置文件中删除该仓库并重试。原因：\n#{stderr}"
              end
            }
            [output, repo]
          end

          def __sync_remote_repo(light_repo, root, link_git:true)
            #
            output, repo = nil, nil
            clone_url = light_repo.clone_url(root)

            Utils.execute_shell_cmd(clone_url) { |stdout, stderr, status|
              if status.success?
                repo = Repo.generate_strictly(root, light_repo)
                begin
                  # 查询配置看是否需要托管.git实体, 根据mgit config -s managegit false配置。
                  # 若是，那么.git实体会放在.mgit/source-git/文件夹下
                  manage_git = MGitConfig.query_with_key(root, :managegit)
                  Utils.link_git(repo.path, light_repo.git_store_dir(root)) if manage_git && link_git
                rescue Error => _
                end
                msg = ''
                # 同步锁定点
                error_message = sync_lock_point(repo, light_repo)
                msg += error_message if !error_message.nil?

                output = msg.length > 0 ? msg : nil
              else
                output = "同步仓库\"#{light_repo.name}\"时clone失败，如果远程仓库不存在，请在配置文件中删除该仓库并重试。原因：\n#{stderr}"
              end
            }

            [output, repo]
          end

          git_entity = File.join(light_repo.git_store_dir(root), '.git')
          if File.exist?(git_entity)
            __sync_local_repo(light_repo, root, link_git: link_git)
          else
            __sync_remote_repo(light_repo, root, link_git: link_git)
          end
        end

        # 同步已有仓库
        #
        # @param repo [Repo] Repo对象
        #
        # @param light_repo [Manifest::LightRepo] LightRepo对象
        #
        # @return [string] 执行结果，成功返回nil，错误返回错误信息
        #
        def sync_exist_repo(repo, light_repo)
          msg = ''

          if light_repo.lock
            # 同步锁定点
            error_message = sync_lock_point(repo, light_repo)
            msg += error_message + "\n" if !error_message.nil?
          end

          # 同步remote url
          error_message = sync_remote_url(repo, light_repo)
          msg += error_message + "\n" if !error_message.nil?

          return msg.length > 0 ? msg : nil
        end

        # 同步锁定点
        #
        # @param repo [Repo] Repo对象
        #
        # @param light_repo [Manifest::LightRepo] LightRepo对象
        #
        # @return [string] 执行结果，成功返回nil，错误返回错误信息
        #
        def sync_lock_point(repo, light_repo)
          if repo.status_checker.status == Status::GIT_REPO_STATUS[:dirty]
            return "#{light_repo.name}有本地改动，无法锁定，请自行清空修改后重试!"
          end

          if !light_repo.commit_id.nil?
            return sync_commit_id(repo, light_repo)
          elsif !light_repo.tag.nil?
            return sync_tag(repo, light_repo)
          elsif !light_repo.branch.nil?
            return sync_branch(repo, light_repo)
          end
        end

        # 同步tag
        # @param repo [Repo] Repo对象
        #
        # @param light_repo [Manifest::LightRepo] LightRepo对象
        #
        # @return [string] 执行结果，成功返回nil，错误返回错误信息
        #
        def sync_tag(repo, light_repo)
          if !light_repo.tag.nil?
            success, output = repo.execute_git_cmd('checkout', light_repo.tag)
            return output if !success
          else
            return "\"#{repo.path}\"的仓库配置未指定tag!"
          end
        end

        # 同步commit id
        # @param repo [Repo] Repo对象
        #
        # @param light_repo [Manifest::LightRepo] LightRepo对象
        #
        # @return [string] 执行结果，成功返回nil，错误返回错误信息
        #
        def sync_commit_id(repo, light_repo)
          if !light_repo.commit_id.nil?
            success, output = repo.execute_git_cmd('checkout', light_repo.commit_id)
            return output if !success
          else
            return "\"#{repo.path}\"的仓库配置未指定commit id!"
          end
        end

        # 同步分支
        #
        # @param repo [Repo] Repo对象
        #
        # @param light_repo [Manifest::LightRepo] LightRepo对象
        #
        # @return [string] 执行结果，成功返回nil，错误返回错误信息
        #
        def sync_branch(repo, light_repo)

          current_branch = repo.status_checker.current_branch(strict_mode:false)
          local_branch_exist = repo.status_checker.local_branch_exist?(light_repo.branch)
          remote_branch_exist = repo.status_checker.remote_branch_exist?(light_repo.branch)
          is_dirty = repo.status_checker.status == Status::GIT_REPO_STATUS[:dirty]

          # 当前已在目标切换分支则不操作
          if current_branch == light_repo.branch
            return nil

            # 本地或远程存在目标分支则切换
          elsif local_branch_exist || remote_branch_exist || Utils.branch_exist_on_remote?(light_repo.branch, light_repo.url)

            # 本地无目标分支则先拉取
            if !local_branch_exist && !remote_branch_exist
              success, error = repo.execute_git_cmd('fetch', '')
              return error if !success
            end

            if !is_dirty
              success, output = repo.execute_git_cmd('checkout', light_repo.branch)
              return output if !success
            else
              return "本地有改动, 无法切换到分支\"#{light_repo.branch}\", 请处理后重试!"
            end

          else
            return "仓库分支\"#{light_repo.branch}\"不存在，请检查是否拼写错误！"
          end

        end

        # 同步remote url
        #
        # @param repo [Repo] Repo对象
        #
        # @param light_repo [Manifest::LightRepo] LightRepo对象
        #
        # @return [Boolean] 执行结果，成功返回nil，错误返回错误信息
        #
        def sync_remote_url(repo, light_repo)
          return nil if light_repo.url.nil?

          success, output = repo.execute_git_cmd('remote', "set-url origin #{light_repo.url}")
          return success ? nil : output
        end

        # 生成本地裸库路径
        #
        # @param repo_name [String] 仓库名
        #
        # @return [String] 本地裸库路径
        #
        def local_bare_git_url(path)
          if File.exist?(path)
            return path
          else
            return nil
          end
        end

        # 删除失效的仓库目录
        #
        # @param repo_abs_path [String] 仓库完整路径
        #
        def delete_legacy_repo(repo_abs_path)
          FileUtils.remove_dir(repo_abs_path, true) if File.exist?(repo_abs_path)
        end

      end

    end
  end
end
