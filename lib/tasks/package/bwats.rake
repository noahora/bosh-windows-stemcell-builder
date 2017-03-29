require 'rspec/core/rake_task'
require 'json'

namespace :package do
	desc 'package bosh-windows-acceptance-tests (BWATS) config.json'
	task :bwats do |t|
		required_vars = [
			'BOSH_CA_CERT', 'BOSH_CLIENT', 'BOSH_CLIENT_SECRET',
			'BOSH_TARGET', 'BOSH_UUID',
			'STEMCELL_PATH', 'AZ', 'VM_TYPE','NETWORK'
		]
		missing_vars = false
		required_vars.each do |var|
			unless ENV[var]
				unless missing_vars
					puts 'Error:'
					missing_vars = true
				end
				puts "Missing required environment variable: #{var}"
			end
		end

		if missing_vars
			raise 'missing environment variables'
		end
		build_dir = File.expand_path('../../../../build', __FILE__)
		config = {
			'bosh' => {
				'ca_cert' => ENV['BOSH_CA_CERT'],
				'client' => ENV['BOSH_CLIENT'],
				'client_secret' => ENV['BOSH_CLIENT_SECRET'],
				'target' => ENV['BOSH_TARGET'],
				'uuid' => ENV['BOSH_UUID']
			},
			'stemcell_path' => ENV['STEMCELL_PATH'],
			'az' => ENV['AZ'],
			'vm_type' => ENV['VM_TYPE'],
			'network' => ENV['NETWORK']
		}
    File.open(File.join(build_dir,'config.json'), 'w') { |file| file.write(JSON.pretty_generate(config)) }
	end
end
