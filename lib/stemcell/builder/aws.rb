module Stemcell
  class Builder
    class Aws < Base
      def initialize(amis:, aws_access_key:, aws_secret_key:, **args)
        @amis = amis
        @aws_access_key = aws_access_key
        @aws_secret_key = aws_secret_key
        super(args)
      end

      def build
        packer_output = Packer::Runner.new(packer_config).run('build', @packer_vars)[1]
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
  end
end
