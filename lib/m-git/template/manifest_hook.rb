#coding=utf-8

module MGit
  module Template
    MANIFEST_HOOK_TEMPLATE = '
#coding=utf-8

module MGitTemplate

  class ManifestHook

    # hook接口，用于生成manifest.json文件。文件本地地址必须设置为<PROJ_ROOT>/.mgit/source-config/manifest.json
    #
    # 若解析失败，可抛出异常：
    #
    #     raise MGit::Error.new("失败原因...", type: MGit::MGIT_ERROR_TYPE[:config_generate_error])
    #
    # 异常抛出后程序终止
    def self.run()

    end

  end

end
  '
  end
end
