#coding=utf-8

module MGit
  module Template
    module_function
    def default_template
      return "{
  \"#{Constants::CONFIG_KEY[:repositories]}\": {

  }
}
"
    end

    def local_config_template(config_repo_name)
      return "{
  \"#{Constants::CONFIG_KEY[:mgit_excluded]}\": true,
  \"#{Constants::CONFIG_KEY[:repositories]}\": {
    \"#{config_repo_name}\": {
      \"#{Constants::REPO_CONFIG_KEY[:mgit_excluded]}\": false
    }
  }
}
"
    end
  end
end
