#!/usr/bin/env ruby

require 'digest'
require 'fileutils'
require 'zlib'
require 'scanf.rb'
require 'tmpdir'
require 'open3'
require 'mkmf'

require_relative '../erb_templates/templates.rb'

# Concourse inputs
VERSION = File.read("version/number").chomp

VMX_DIR = ENV.fetch("VMX_DIR")
ADMINISTRATOR_PASSWORD = ENV.fetch('ADMINISTRATOR_PASSWORD')
BUILDER_PATH=File.expand_path("../..", __FILE__)
OUTPUT_DIR = ENV.fetch("OUTPUT_DIR")

puts "VMX_DIR: #{VMX_DIR}"
puts "VERSION: #{VERSION}"
puts "ADMINISTRATOR_PASSWORD: #{ADMINISTRATOR_PASSWORD}"
puts "BUILDER_PATH: #{BUILDER_PATH}"
puts "OUTPUT_DIR: #{OUTPUT_DIR}"

def gzip_file(name, output)
  Zlib::GzipWriter.open(output) do |gz|
   File.open(name) do |fp|
     while chunk = fp.read(32 * 1024) do
       gz.write chunk
     end
   end
   gz.close
  end
end

def exec_command(cmd)
  Open3.popen2(cmd) do |stdin, out, wait_thr|
    out.each_line do |line|
      puts line
    end
    exit_status = wait_thr.value
    if exit_status != 0
      raise "error running command: #{cmd}"
    end
  end
end

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

# make sure we have ovftool and packer
if find_executable('ovftool') == nil
  abort("ERROR: cannot find 'ovftool' on the path")
end
if find_executable('packer') == nil
  abort("ERROR: cannot find 'packer' on the path")
end
if find_executable('tar') == nil
  abort("ERROR: cannot find 'tar' on the path")
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

FileUtils.mkdir_p(OUTPUT_DIR)
output_dir = File.absolute_path(OUTPUT_DIR)

stemcell_filename = File.join(output_dir, "bosh-stemcell-#{VERSION}-vsphere-esxi-windows2012R2-go_agent.tgz")
puts "stemcell_filename: #{stemcell_filename}"
if File.exists?(stemcell_filename)
  raise "stemcell with name (#{stemcell_filename}) already exists - refusing to overwrite!"
end

begin
  stemcell_vars = {
    'source_path' => latest_vmx,
    'output_directory' => dir,
    'administrator_password' => ADMINISTRATOR_PASSWORD
  }

  packer_config = File.join(BUILDER_PATH, "vmx", "stemcell.json")
  packer_command('build', packer_config, stemcell_vars)

  stemcell_vmx = find_vmx_file(dir)
  puts "stemcell_vmx: #{stemcell_vmx}"

  ova_file = File.join(dir, 'image.ova')
  exec_command("ovftool #{stemcell_vmx} #{ova_file}")

  image_file = File.join(dir, 'image')
  puts "image_file: #{image_file}"

  gzip_file(ova_file, image_file)
  image_sha1 = Digest::SHA1.file(image_file).hexdigest
  MFTemplate.new("#{BUILDER_PATH}/erb_templates/vsphere/stemcell.MF.erb", VERSION, sha1: image_sha1).save(dir)

  exec_command("tar czvf #{stemcell_filename} -C #{dir} stemcell.MF image")
ensure
  puts "removing temp directory: #{dir}"
  if File.exists?(dir)
    FileUtils.remove_entry dir
  end
end
