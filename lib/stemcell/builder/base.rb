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
  end
end
