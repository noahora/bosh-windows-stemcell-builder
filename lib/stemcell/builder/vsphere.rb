require 'digest'
require 'tmpdir'
require 'zlib'

module Stemcell
  class Builder
    class VSphereAddUpdates < Base
      def initialize(source_path:, administrator_password:, mem_size: 4096, num_vcpus: 4, **args)
        @source_path = source_path
        @administrator_password = administrator_password
        @mem_size = mem_size
        @num_vcpus = num_vcpus
        super(args)
      end

      def build
      end

      private
      def packer_config
        Packer::Config::VSphereAddUpdates.new().dump
      end

      def run_packer
        exit_status = Packer::Runner.new(packer_config).run('build', @packer_vars) do |out|
          puts out
        end
        if exit_status != 0
          raise PackerFailure
        end
      end
    end

    class VSphere < Base
      def initialize(source_path:, administrator_password:,
                     mem_size:, num_vcpus:,
                     product_key:,
                     owner:, organization:, **args)
        @source_path = source_path
        @administrator_password = administrator_password
        @mem_size = mem_size
        @num_vcpus = num_vcpus
        @product_key = product_key
        @owner = owner
        @organization = organization
        super(args)
      end

      def build
        run_packer(@output_dir)
        image_path, sha = create_image(@output_dir)
        manifest = Manifest::VSphere.new(@version, sha, @os).dump
        super(iaas: 'vsphere-esxi', is_light: false, image_path: image_path, manifest: manifest)
      end

      private

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

      def gzip_file(name, output)
        Zlib::GzipWriter.open(output) do |gz|
          File.open(name) do |fp|
            while chunk = fp.read(32 * 1024) do
              gz.write chunk
            end
          end
          gz.close
        end
      end

      def create_image(vmx_dir)
        sha1_sum=''
        image_file = File.join(vmx_dir, 'image')
        Dir.mktmpdir do |tmpdir|
          vmx_file = find_vmx_file(vmx_dir)
          ova_file = File.join(tmpdir, 'image.ova')
          exec_command("ovftool #{vmx_file} #{ova_file}")
          gzip_file(ova_file, image_file)
          sha1_sum = Digest::SHA1.file(image_file).hexdigest
        end
        [image_file,sha1_sum]
      end

      def packer_config(vmx_output_dir)
        Packer::Config::VSphere.new(
          @administrator_password, @source_path,
          vmx_output_dir, @mem_size, @num_vcpus,
          @product_key,@owner, @organization
        ).dump
      end

      def run_packer(vmx_output_dir)
        config = packer_config(vmx_output_dir)
        exit_status = Packer::Runner.new(config).run('build', @packer_vars) do |out|
          out.each_line do |line|
            puts line
          end
        end
        if exit_status != 0
          raise PackerFailure
        end
      end
    end
  end
end
