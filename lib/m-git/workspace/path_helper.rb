
module MGit
  class Workspace

    # .mgit 目录下的文件路径
    #
    module PathHelper

      # .mgit/config.yml
      #
      def config_file
        File.join(root, Constants::MGIT_CONFIG_PATH)
      end

      # .mgit/hooks
      #
      def hooks_dir
        File.join(root, Constants::PROJECT_DIR[:hooks])
      end

      # .mgit/snapshot
      #
      def snapshot_dir
        File.join(root, Constants::PROJECT_DIR[:snapshot])
      end

      # .mgit/source-config
      #
      def source_config_dir
        File.join(root, Constants::PROJECT_DIR[:source_config])
      end

      # .mgit/source-git
      def source_git_dir
        File.join(root, Constants::PROJECT_DIR[:source_git])
      end
      ########################### manifest ##########################

      def manifest_path
        manifest_name = Constants::CONFIG_FILE_NAME[:manifest]
        File.join(source_config_dir, manifest_name)
      end

      def local_manifest_path
        manifest_name = Constants::CONFIG_FILE_NAME[:local_manifest]
        File.join(source_config_dir, manifest_name)
      end

      def cache_manifest_path
        file_name = Constants::CONFIG_FILE_NAME[:manifest_cache]
        File.join(source_config_dir, file_name)
      end

    end
  end
end
