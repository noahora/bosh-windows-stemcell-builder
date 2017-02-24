module Stemcell
  class Builder
    class Base
      def initialize(os:, output_dir:, version:, agent_commit:, packer_vars:)
        @os = os
        @output_dir = output_dir
        @version = version
        @agent_commit = agent_commit
        @packer_vars = packer_vars
      end

      def build(iaas:, is_light:, image_path:, manifest:)
        apply_spec = ApplySpec.new(@agent_commit).dump
        Packager.package(iaas: iaas, os: @os, is_light: is_light, version: @version, image_path: image_path, manifest: manifest,
                     apply_spec: apply_spec, output_dir: @output_dir)
      end

      private

        def exec_command(cmd)
          `#{cmd}`
          raise "command '#{cmd}' failed" unless $?.success?
        end
    end

    class Aws < Base
      def initialize(amis:, aws_access_key:, aws_secret_key:, **args)
        @amis = amis
        @aws_access_key = aws_access_key
        @aws_secret_key = aws_secret_key
        super(args)
      end

      def build
        packer_output = Packer::Runner.new(packer_config).run('build', @packer_vars)
        parsed_packer_amis = parse_amis(packer_output)
        manifest = Manifest::Aws.new(@version, @os, parsed_packer_amis).dump
        super(iaas: 'aws', is_light: true, image_path: '', manifest: manifest)
      end

      private

        def packer_config
          Packer::Config::Aws.new(@aws_access_key, @aws_secret_key, @amis).dump
        end

        def parse_amis(packer_output)
          amis = []
          packer_output.each_line do |line|
            ami = parse_ami(line)
            if !ami.nil?
              amis.push(ami)
            end
          end
          return amis
        end

        def parse_ami(line)
          unless line.include?(",artifact,0,id,")
            return
          end

          region_id = line.split(",").last.split(":")
          return {:region=> region_id[0].chomp, :ami_id=> region_id[1].chomp}
        end
    end

    class Gcp < Base
      def initialize(account_json:, **args)
        @account_json = account_json
        super(args)
      end

      def build
        image_url = get_image
        manifest = Manifest::Gcp.new(@version, @os, image_url).dump
        super(iaas: 'gcp', is_light: true, image_path: '', manifest: manifest)
      end

      private
        def packer_config
          Packer::Config::Gcp.new(@account_json).dump
        end

        def get_image
          packer_output = Packer::Runner.new(packer_config).run('build', @packer_vars)
          image_url = nil
          packer_output.each_line do |line|
            # puts line
            image_url ||= parse_image_url(line)
          end
          image_url
        end

        def parse_image_url(line)
          if line.include?(",artifact,0,id,")
            return line.split(",").last.chomp
          end
        end
    end

    class Azure < Base
      def build
        image_path = get_image
        sha = Digest::SHA1.file(image_path).hexdigest
        manifest = Manifest::Azure.new('bosh-azure-stemcell-name', @version, sha, @os).dump
        super(iaas: 'azure', is_light: false, image_path: image_path, manifest: manifest)
      end

      private
        def packer_config
          Packer::Config::Azure.new().dump
        end

        def get_image
          packer_output = Packer::Runner.new(packer_config).run('build', @packer_vars)
          disk_uri = nil
          packer_output.each_line do |line|
            # puts line
            disk_uri ||= parse_disk_uri(line)
          end
          download_disk(disk_uri)
          Packager.package_image(image_path: "#{@output_dir}/root.vhd", archive: true, output_dir: @output_dir)
        end

        def parse_disk_uri(line)
          unless line.include?("azure-arm,artifact,0") and line.include?("OSDiskUriReadOnlySas:")
            return
          end
          (line.split '\n').select do |s|
            s.start_with?("OSDiskUriReadOnlySas: ")
          end.first.gsub("OSDiskUriReadOnlySas: ", "")
        end

        def download_disk(disk_uri)
          exec_command("curl -s -o '#{@output_dir}/root.vhd' '#{disk_uri}'")
        end
    end
  end
end
