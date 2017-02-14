#!/usr/bin/env ruby

require 'open3'

SOURCE_PATH =  ENV.fetch("SOURCE_PATH")
ADMINISTRATOR_PASSWORD = ENV.fetch('ADMINISTRATOR_PASSWORD')
BUILDER_PATH=File.expand_path("../..", __FILE__)
OUTPUT_DIR = ENV.fetch("OUTPUT_DIR")

def packer_command(command, config_path, vars)
  Dir.chdir(File.dirname(config_path)) do

    args = %{
      packer #{command} \
      -var "source_path=#{vars['source_path']}" \
      -var "administrator_password=#{vars['administrator_password']}" \
      -var "output_directory=#{vars['output_directory']}" \
      #{config_path}
    }

    Open3.popen2e(args) do |stdin, stdout_stderr, wait_thr|
      stdout_stderr.each_line do |line|
        puts line
      end
      exit_status = wait_thr.value
      if exit_status != 0
        puts "packer failed #{exit_status}"
        exit(1)
      end
    end
  end
end

update_vars = {
  'source_path' => SOURCE_PATH,
  'output_directory' => OUTPUT_DIR,
  'administrator_password' => ADMINISTRATOR_PASSWORD
}

# packer_command
packer_config = File.join(BUILDER_PATH, "vmx", "updates.json")

packer_command('validate', packer_config, update_vars)
packer_command('build', packer_config, update_vars)
