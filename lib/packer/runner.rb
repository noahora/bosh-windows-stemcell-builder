require 'tempfile'
require 'json'
require 'English'

module Packer
  class Runner
    class ErrorInvalidConfig < RuntimeError
    end

    def initialize(config)
      @config = config
    end

    def run(command, args={})
      config_file = Tempfile.new('')
      config_file.write(JSON.dump(@config))
      config_file.close

      args_combined = ''
      args.each do |name, value|
        args_combined += "-var \"#{name}=#{value}\""
      end

      output = `packer #{command} -machine-readable #{args_combined} #{config_file.path}`
      [$CHILD_STATUS.exitstatus, output]
    end
  end
end
