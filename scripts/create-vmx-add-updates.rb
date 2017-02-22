#!/usr/bin/env ruby

require 'open3'
require 'tmpdir'
require 'scanf.rb'
require 'fileutils'

VMX_DIR = ENV.fetch("VMX_DIR")
ADMINISTRATOR_PASSWORD = ENV.fetch('ADMINISTRATOR_PASSWORD')
BUILDER_PATH = File.expand_path("../..", __FILE__)

puts "VMX_DIR: #{VMX_DIR}"
puts "ADMINISTRATOR_PASSWORD: #{ADMINISTRATOR_PASSWORD}"
puts "BUILDER_PATH: #{BUILDER_PATH}"

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
        raise "packer failed #{exit_status}"
      end
    end
  end
end

def find_latest_vmx_dir(parent_dir)
  latest_version = -1
  latest_dirname = nil
  pattern = File.join(parent_dir, '**/base-vmx-*').gsub('\\', '/')

  Dir.glob(pattern) do |dirname|
    puts "dirname: #{dirname}"

    base = File.basename(dirname)
    puts "base: #{base}"

    version = base.scanf("base-vmx-%d")[0]
    if version
      version_number = version.to_i
      if version_number > latest_version
        latest_version = version_number
        latest_dirname = dirname
      end
    end
  end

  if latest_version == -1
    raise "Failed to find any vmx dirs in: #{parent_dir}"
  end
  return latest_dirname, latest_version
end

def find_vmx_file(dir)
  pattern = File.join(dir, "*.vmx").gsub('\\', '/')
  files = Dir.glob(pattern)
  if files.length == 0
    raise "No vmx files in directory: #{dir}"
  end
  if files.length > 1
    raise "Too many vmx files in directory: #{files}"
  end
  return files[0]
end

def tmpdir_name
  path = File.join(Dir.tmpdir(), "packer-#{Time.now.to_i}")
  n = 0
  while File.exists?(path) && n < 100
    path = File.join(Dir.tmpdir(), "packer-#{Time.now.to_i}-#{n}")
    n += 1
  end
  if n == 100
    raise "Error finding unique name for tmpdir!"
  end
  return File.absolute_path(path)
end

latest_dirname, latest_version = find_latest_vmx_dir(VMX_DIR)
puts "latest vmx directory: #{latest_dirname}"
puts "latest vmx version: #{latest_version}"

latest_vmx = find_vmx_file(latest_dirname)
puts "latest vmx file: #{latest_vmx}"

new_dirname = File.join(VMX_DIR, "base-vmx-#{latest_version+1}")
puts "new vmx directory: #{new_dirname}"

dir = tmpdir_name()
puts "temporary directory: #{dir}"

begin
  update_vars = {
    'source_path' => latest_vmx,
    'output_directory' => dir,
    'administrator_password' => ADMINISTRATOR_PASSWORD
  }

  packer_config = File.join(BUILDER_PATH, "vmx", "updates.json")
  packer_command('build', packer_config, update_vars)

  puts "moving dir (#{dir}) to (#{new_dirname})"
  FileUtils.mv(dir, new_dirname)
ensure
  puts "removing temp directory: #{dir}"
  if File.exists?(dir)
    FileUtils.remove_entry dir
  end
end
