require 'stemcell/builder'

describe Stemcell::Builder do
  output_dir = ''

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      output_dir = dir
      example.run
    end
  end

  fdescribe 'Azure' do
    describe 'build' do
      it 'builds a stemcell tarball' do
        os = 'windows2012R2'
        version = '1234.0'
        agent_commit = 'some-agent-commit'
        name = 'bosh-azure-stemcell-name'
        sha = 'da39a3ee5e6b4b0d3255bfef95601890afd80709'
        config = 'some-packer-config'
        command = 'build'
        packer_vars = {some_var: 'some-value'}

        packer_runner = double(:packer_runner)
        File.new(File.join(output_dir, 'disk-image'), "w+")
        allow(packer_runner).to receive(:run).with(command, packer_vars).and_return("azure-arm,artifact,0\\nOSDiskUriReadOnlySas: file://#{File.join(output_dir, 'disk-image')}")
        azure_manifest = double(:azure_manifest)
        allow(azure_manifest).to receive(:dump).and_return('manifest-contents')
        azure_apply = double(:azure_apply)
        allow(azure_apply).to receive(:dump).and_return('apply-spec-contents')

        allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)
        allow(Stemcell::Manifest::Azure).to receive(:new).with(name, version, sha, os).and_return(azure_manifest)
        allow(Stemcell::ApplySpec).to receive(:new).with(agent_commit).and_return(azure_apply)
        allow(Stemcell::Packager).to receive(:package).with(iaas: 'azure',
                                                            os: os,
                                                            is_light: false,
                                                            version: version,
                                                            image_path: File.join(output_dir, 'image'),
                                                            manifest: 'manifest-contents',
                                                            apply_spec: 'apply-spec-contents',
                                                            output_dir: output_dir
                                                           ).and_return('path-to-stemcell')

        stemcell_path = Stemcell::Builder::Azure.new(
          os: os,
          output_dir: output_dir,
          version: version,
          agent_commit: agent_commit,
          packer_vars: packer_vars
        ).build
        expect(stemcell_path).to eq('path-to-stemcell')
      end
    end
  end
  describe 'Aws' do
    describe 'build' do
      it 'builds a stemcell tarball' do
        os = 'windows2012R2'
        version = '1234.0'
        amis = 'some-amis'
        agent_commit = 'some-agent-commit'

        aws_manifest = double(:aws_manifest)
        allow(aws_manifest).to receive(:dump).and_return('manifest-contents')
        aws_apply = double(:aws_apply)
        allow(aws_apply).to receive(:dump).and_return('apply-spec-contents')
        allow(Stemcell::Manifest::Aws).to receive(:new).with(version, os, amis).and_return(aws_manifest)
        allow(Stemcell::ApplySpec).to receive(:new).with(agent_commit).and_return(aws_apply)
        allow(Stemcell::Packager).to receive(:package).with(iaas: 'aws',
                                                            os: os,
                                                            is_light: true,
                                                            version: version,
                                                            image_path: '',
                                                            manifest: 'manifest-contents',
                                                            apply_spec: 'apply-spec-contents',
                                                            output_dir: output_dir
                                                           ).and_return('path-to-stemcell')

        stemcell_path = Stemcell::Builder::Aws.new(os: os, output_dir: output_dir, version: version, amis: amis, agent_commit: agent_commit).build
        expect(stemcell_path).to eq('path-to-stemcell')
      end
    end
  end
end
