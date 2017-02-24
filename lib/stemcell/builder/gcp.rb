module Stemcell
  class Builder
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
  end
end
