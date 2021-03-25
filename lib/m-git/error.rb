#coding=utf-8

module MGit

  MGIT_ERROR_TYPE = {
    :config_name_error => 'config_name_error',
    :config_generate_error => 'config_generate_error'
  }.freeze

  class Error < StandardError
    attr_reader :msg
    attr_reader :type

    def initialize(msg, type:nil)
      @msg = msg
      @type = type
    end
  end

end
