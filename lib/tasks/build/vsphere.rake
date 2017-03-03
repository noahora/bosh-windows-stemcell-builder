require 'rspec/core/rake_task'
require 'json'

namespace :build do
  task :vsphere do

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

    build_dir = File.expand_path("../../../../build", __FILE__)

    version = File.read(File.join(build_dir, 'version', 'number')).chomp
    vmx_version = File.read(File.join(build_dir, 'vmx-version', 'number')).chomp
    agent_commit = File.read(File.join(build_dir, 'compiled-agent', 'sha')).chomp

    FileUtils.mkdir_p(ENV.fetch('OUTPUT_DIR'))

    vsphere_builder = Stemcell::Builder::VSphere.new(
      administrator_password: ENV.fetch("ADMINISTRATOR_PASSWORD"),
      input_bucket: ENV.fetch("INPUT_BUCKET"),
      output_bucket: ENV.fetch("OUTPUT_BUCKET"),
      vmx_cache_dir: ENV.fetch("VMX_CACHE_DIR"),
      product_key: ENV.fetch("PRODUCT_KEY"),
      owner: ENV.fetch("OWNER"),
      organization: ENV.fetch("ORGANIZATION"),
      agent_commit: agent_commit,
      os: ENV.fetch("OS_VERSION"),
      output_dir: ENV.fetch("OUTPUT_DIR"),
      packer_vars: {},
      source_image: base_image,
      version: version
    )

    begin
      vsphere_builder.build
    rescue => e
      puts "Failed to build stemcell: #{e.message}"
      puts e.backtrace
    end

  end
end
