require 'rspec/core/rake_task'
require 'json'

namespace :build do
  namespace :vsphere do

    def find_vmx_file(dir)
      pattern = File.join(dir, "*.vmx").gsub('\\', '/')
      files = Dir.glob(pattern)
      if files.length == 0
        raise "No vmx files in directory: #{dir}"
      end
      if files.length > 1
        raise "Too many vmx files in directory: #{files}"
      end
      return files[0]
    end

    # def foo
    # build_dir = File.expand_path("../../../../build", __FILE__)

    # version = File.read(File.join(build_dir, 'version', 'number')).chomp
    # agent_commit = File.read(File.join(build_dir, 'compiled-agent', 'sha')).chomp

    # # FileUtils.mkdir_p(ENV.fetch('OUTPUT_DIR'))

    # begin
    #   gcp_builder.build
    # rescue => e
    #   puts "Failed to build stemcell: #{e.message}"
    #   puts e.backtrace
    # end

    # end

    task :updates do
    end

    task :stemcell do
    end
  end
end
