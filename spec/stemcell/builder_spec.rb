require 'stemcell/builder'

describe Stemcell::Builder do
  output_dir = ''

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      output_dir = dir
      example.run
    end
  end

  describe 'GCP' do
    describe 'build' do
      it 'builds a stemcell tarball' do
        os = 'windows2012R2'
        version = '1234.0'
        agent_commit = 'some-agent-commit'
        config = 'some-packer-config'
        command = 'build'
        manifest_contents = 'manifest_contents'
        apply_spec_contents = 'apply_spec_contents'
        packer_vars = {some_var: 'some-value'}
        image_url = 'some-image-url'
        account_json = 'some-account-json'

        packer_config = double(:packer_config)
        allow(packer_config).to receive(:dump).and_return(config)
        allow(Packer::Config::Gcp).to receive(:new).with(account_json).and_return(packer_config)

        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with(command, packer_vars).and_return(",artifact,0,id,#{image_url}")
        allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)

        gcp_manifest = double(:gcp_manifest)
        allow(gcp_manifest).to receive(:dump).and_return(manifest_contents)
        gcp_apply = double(:gcp_apply)
        allow(gcp_apply).to receive(:dump).and_return(apply_spec_contents)

        allow(Stemcell::Manifest::Gcp).to receive(:new).with(version, os, image_url).and_return(gcp_manifest)
        allow(Stemcell::ApplySpec).to receive(:new).with(agent_commit).and_return(gcp_apply)
        allow(Stemcell::Packager).to receive(:package).with(iaas: 'gcp',
                                                            os: os,
                                                            is_light: true,
                                                            version: version,
                                                            image_path: '',
                                                            manifest: manifest_contents,
                                                            apply_spec: apply_spec_contents,
                                                            output_dir: output_dir
                                                           ).and_return('path-to-stemcell')

        stemcell_path = Stemcell::Builder::Gcp.new(
          os: os,
          output_dir: output_dir,
          version: version,
          agent_commit: agent_commit,
          packer_vars: packer_vars,
          account_json: account_json
        ).build
        expect(stemcell_path).to eq('path-to-stemcell')
      end
    end
  end
  describe 'Azure' do
    describe 'build' do
      it 'builds a stemcell tarball' do
        os = 'windows2012R2'
        version = '1234.0'
        agent_commit = 'some-agent-commit'
        name = 'bosh-azure-stemcell-name'
        config = 'some-packer-config'
        command = 'build'
        manifest_contents = 'manifest_contents'
        apply_spec_contents = 'apply_spec_contents'
        packer_vars = {some_var: 'some-value'}
        downloaded_image_path = File.join(output_dir, 'root.vhd')
        File.new(downloaded_image_path, "w+")
        packaged_image_path = File.join(output_dir, 'image')
        File.new(packaged_image_path, 'w+')
        sha = Digest::SHA1.file(packaged_image_path).hexdigest

        packer_config = double(:packer_config)
        allow(packer_config).to receive(:dump).and_return(config)
        allow(Packer::Config::Azure).to receive(:new).and_return(packer_config)

        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with(command, packer_vars).and_return("azure-arm,artifact,0\\nOSDiskUriReadOnlySas: file://#{downloaded_image_path}")
        allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)

        allow(Stemcell::Packager).to receive(:package_image)
          .with(image_path: downloaded_image_path, archive: true, output_dir: output_dir)
          .and_return(packaged_image_path)

        azure_manifest = double(:azure_manifest)
        allow(azure_manifest).to receive(:dump).and_return(manifest_contents)
        azure_apply = double(:azure_apply)
        allow(azure_apply).to receive(:dump).and_return(apply_spec_contents)

        allow(Stemcell::Manifest::Azure).to receive(:new).with(name, version, sha, os).and_return(azure_manifest)
        allow(Stemcell::ApplySpec).to receive(:new).with(agent_commit).and_return(azure_apply)
        allow(Stemcell::Packager).to receive(:package).with(iaas: 'azure',
                                                            os: os,
                                                            is_light: false,
                                                            version: version,
                                                            image_path: packaged_image_path,
                                                            manifest: manifest_contents,
                                                            apply_spec: apply_spec_contents,
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
        packer_amis = ",artifact,0,id,some-region-id:some-ami-id"
        parsed_packer_amis = [{region: 'some-region-id', ami_id: 'some-ami-id'}]
        aws_access_key = 'some-aws-access-key'
        aws_secret_key = 'some-aws-secret-key'
        packer_vars = 'some-packer-vars'

        packer_config = double(:packer_config)
        allow(packer_config).to receive(:dump).and_return('some-packer-config')
        allow(Packer::Config::Aws).to receive(:new).with(aws_access_key, aws_secret_key, amis).and_return(packer_config)

        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with('build', packer_vars).and_return(packer_amis)
        allow(Packer::Runner).to receive(:new).with('some-packer-config').and_return(packer_runner)

        aws_manifest = double(:aws_manifest)
        allow(aws_manifest).to receive(:dump).and_return('manifest-contents')
        aws_apply = double(:aws_apply)
        allow(aws_apply).to receive(:dump).and_return('apply-spec-contents')
        allow(Stemcell::Manifest::Aws).to receive(:new).with(version, os, parsed_packer_amis).and_return(aws_manifest)
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

        stemcell_path = Stemcell::Builder::Aws.new(
          os: os,
          output_dir: output_dir,
          version: version,
          amis: amis,
          aws_access_key: aws_access_key,
          aws_secret_key: aws_secret_key,
          agent_commit: agent_commit,
          packer_vars: packer_vars
        ).build
        expect(stemcell_path).to eq('path-to-stemcell')
      end
    end
  end
end
