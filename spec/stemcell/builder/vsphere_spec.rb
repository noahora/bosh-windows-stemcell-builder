require 'stemcell/builder'

describe Stemcell::Builder do
  output_dir = ''

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      output_dir = dir
      example.run
    end
  end

  # TODO
  # describe 'VSphereAddUpdates' do
  #   describe 'build' do
      # it 'builds a vmx from a source vmx'
        # source_vmx = 'my-vmx'
        # admin_password = 'my-password'
        # mem_size = 1024
        # num_vcpus = 1
        # command = 'build'
        # packer_vars = {some_var: 'some-value'}

        # packer_runner = double(:packer_runner)
        # allow(packer_runner).to receive(:run).with(command, packer_vars).
        #   and_yield(packer_output).and_return(0)
        # allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)

        # packer_config = double(:packer_config)
        # allow(packer_config).to receive(:dump).and_return(config)

        # allow(Packer::Config::VSphereAddUpdates).to receive(:new).with(admin_password,
        #   source_path, output_directory, mem_size, num_vcpus).and_return(packer_config)

        # Stemcell::Builder::VSphereAddUpdates.new(
        #   source_vmx: source_vmx,
        #   admin_password: admin_password,
        #   mem_size: mem_size,
        #   num_vcpus: num_vcpus,
        #   output_dir: output_dir,
        #   packer_vars: packer_vars
        # ).build
        # expect(_path).to eq('path-to-stemcell')
      # end
      #
      #
      # context 'when packer fails' do
        # it 'raises an error' do
        # end

      #   it 'does not add the VM to the VMX directory' do
      #   end
      # end
  #   end
  # end

  describe 'VSphere' do
    describe 'build' do
      it 'builds a stemcell tarball' do
        administrator_password = 'my-password'
        input_bucket= 'in-bucket'
        output_bucket= 'out-bucket'
        vmx_cache_dir= 'vmx-cache-dir'
        product_key = 'product-key'
        owner = 'owner'
        organization = 'organization'
        mem_size = '4'
        num_vcpus = '8'
        config = 'some-packer-config'
        version = 'stemcell-version'
        manifest_contents = 'manifest_contents'
        apply_spec_contents = 'apply_spec_contents'
        agent_commit = 'some-agent-commit'
        sha = 'sha'
        os = 'windows2012R2'
        command = 'build'
        packer_vars = {some_var: 'some-value'}
        packer_output = ''
        source_path = ''
        output_directory = ''

        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with(command, packer_vars).
          and_yield(packer_output).and_return(0)
        allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)

        packer_config = double(:packer_config)
        allow(packer_config).to receive(:dump).and_return(config)

        allow(Packer::Config::VSphere).to receive(:new).with(administrator_password,
          source_path, output_directory, mem_size, num_vcpus, product_key,
          owner, organization).and_return(packer_config)

        vsphere_manifest = double(:vsphere_manifest)
        allow(vsphere_manifest).to receive(:dump).and_return(manifest_contents)

        vsphere_apply = double(:vsphere_apply)
        allow(vsphere_apply).to receive(:dump).and_return(apply_spec_contents)

        allow(Stemcell::Manifest::VSphere).to receive(:new).with(version, sha, os).and_return(vsphere_manifest)
        allow(Stemcell::ApplySpec).to receive(:new).with(agent_commit).and_return(vsphere_apply)
        allow(Stemcell::Packager).to receive(:package).with(iaas: 'vsphere',
                                                            os: os,
                                                            is_light: true,
                                                            version: version,
                                                            image_path: '',
                                                            manifest: manifest_contents,
                                                            apply_spec: apply_spec_contents,
                                                            output_dir: output_dir
                                                           ).and_return('path-to-stemcell')

        Stemcell::Builder::VSphere.new(
          administrator_password: administrator_password,
          input_bucket: input_bucket,
          output_bucket: output_bucket,
          vmx_cache_dir: vmx_cache_dir,
          product_key: product_key,
          owner: owner,
          organization: organization
        ).build
        expect(_path).to eq('path-to-stemcell')
      end

      # TODO
      # context 'when packer fails' do
      #   it 'raises an error' do
      #   end
      # end
    end
  end
end
