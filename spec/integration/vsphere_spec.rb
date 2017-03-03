require 'fileutils'
require 'json'
require 'rake'
require 'rubygems/package'
require 'tmpdir'
require 'yaml'
require 'zlib'

load File.expand_path('../../../lib/tasks/build/vsphere.rake', __FILE__)

describe 'VSphere' do
  before(:each) do
    @original_env = ENV.to_hash
    @build_dir = File.expand_path('../../../build', __FILE__)
    FileUtils.mkdir_p(@build_dir)
  end

  after(:each) do
    ENV.replace(@original_env)
    FileUtils.remove_dir(@build_dir)
  end

  it 'should build a vsphere stemcell' do
    Dir.mktmpdir('vsphere-stemcell-test') do |tmpdir|
      output_dir = File.join(tmpdir, 'vsphere')
      os_version = 'some-os-version'
      version = 'some-version'
      agent_commit = 'some-agent-commit'

      ENV['ADMINISTRATOR_PASSWORD'] = 'pass'
      ENV['INPUT_BUCKET'] = 'input-vmx-bucket'
      ENV['VMX_CACHE_DIR'] = '/tmp'
      ENV['OUTPUT_BUCKET'] = 'stemcell-output-bucket'

      ENV['PRODUCT_KEY'] = 'product-key'
      ENV['OWNER'] = 'owner'
      ENV['ORGANIZATION'] = 'organization'

      ENV['OS_VERSION'] = os_version
      ENV['OUTPUT_DIR'] = output_dir
      ENV['PATH'] = "#{File.join(@build_dir, '..', 'spec', 'fixtures', 'vsphere')}:#{ENV['PATH']}"

      FileUtils.mkdir_p(File.join(@build_dir, 'version'))
      File.write(
        File.join(@build_dir, 'version', 'number'),
        version
      )
      FileUtils.mkdir_p(File.join(@build_dir, 'vmx-version'))
      File.write(
        File.join(@build_dir, 'vmx-version', 'number'),
        'some-vmx-version'
      )

      Rake::Task['build:vsphere'].invoke

      stemcell = File.join(output_dir, "bosh-stemcell-#{version}-vsphere-esxi-#{os_version}-go_agent.tgz")

      # stemcell_manifest = YAML.load(read_from_tgz(stemcell, 'stemcell.MF'))
      # expect(stemcell_manifest['version']).to eq(version)
      # expect(stemcell_manifest['sha1']).to eq(EMPTY_FILE_SHA)
      # expect(stemcell_manifest['operating_system']).to eq(os_version)
      # expect(stemcell_manifest['cloud_properties']['infrastructure']).to eq('aws')
      # expect(stemcell_manifest['cloud_properties']['ami']['us-east-1']).to eq('ami-east1id')
      # expect(stemcell_manifest['cloud_properties']['ami']['us-east-2']).to eq('ami-east2id')

      # apply_spec = JSON.parse(read_from_tgz(stemcell, 'apply_spec.yml'))
      # expect(apply_spec['agent_commit']).to eq(agent_commit)

      expect(read_from_tgz(stemcell, 'image')).to be_nil
    end
  end
end
