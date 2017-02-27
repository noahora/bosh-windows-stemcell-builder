#!/usr/bin/env ruby

require 'digest'
require 'fileutils'
require 'zlib'
require 'scanf.rb'
require 'tmpdir'
require 'open3'
require 'mkmf'
require_relative '../erb_templates/templates.rb'
require_relative './s3-client.rb'


# Concourse inputs
VERSION = File.read("version/number").chomp
ADMINISTRATOR_PASSWORD = ENV.fetch('ADMINISTRATOR_PASSWORD')
BUILDER_PATH=File.expand_path("../..", __FILE__)
OUTPUT_DIR = File.absolute_path("bosh-windows-stemcell")

#S3 inputs
INPUT_BUCKET= ENV.fetch("INPUT_BUCKET")
INPUT_VMX_VERSION= ENV.fetch("INPUT_VMX_VERSION")
OUTPUT_BUCKET= ENV.fetch("OUTPUT_BUCKET")
VMX_CACHE= ENV.fetch("VMX_CACHE")


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

if find_executable('ovftool') == nil
  abort("ERROR: cannot find 'ovftool' on the path")
end

if find_executable('packer') == nil
  abort("ERROR: cannot find 'packer' on the path")
end
if find_executable('tar') == nil
  abort("ERROR: cannot find 'tar' on the path")
end

FileUtils.mkdir_p(VMX_CACHE)
vmx_filename = File.join(VMX_CACHE,"vmx-v#{INPUT_VMX_VERSION}.tgz")
if !File.exist?(vmx_filename)
  S3Client.new().Get(INPUT_BUCKEt,"vmx-v#{INPUT_VMX_VERSION}.tgz",vmx_filename)
else
  puts "VMX file #{vmx_filename} found in cache."
end

VMX_DIR=File.join(VMX_CACHE,INPUT_VMX_VERSION)
if !Dir.exist?(VMX_DIR)
  FileUtils.mkdir_p(VMX_DIR)
  exec_command("tar.exe -xzvf #{vmx_filename} -C #{VMX_DIR}")
else
  puts "VMX dir #{VMX_DIR} found in cache."
end

puts "VMX_DIR: #{VMX_DIR}"
puts "VERSION: #{VERSION}"
puts "ADMINISTRATOR_PASSWORD: #{ADMINISTRATOR_PASSWORD}"
puts "BUILDER_PATH: #{BUILDER_PATH}"
puts "OUTPUT_DIR: #{OUTPUT_DIR}"

latest_vmx = find_vmx_file(VMX_DIR)
output_dir = OUTPUT_DIR
stemcell_filename = File.join(output_dir, "bosh-stemcell-#{VERSION}-vsphere-esxi-windows2012R2-go_agent.tgz")

begin
  stemcell_vars = {
    'source_path' => latest_vmx,
    'output_directory' => output_dir,
    'administrator_password' => ADMINISTRATOR_PASSWORD
  }

  packer_config = File.join(BUILDER_PATH, "vmx", "stemcell.json")
  packer_command('build', packer_config, stemcell_vars)

  stemcell_vmx = find_vmx_file(dir)
  puts "new stemcell_vmx: #{stemcell_vmx}"

  ova_file = File.join(output_dir, 'image.ova')
  exec_command("ovftool #{stemcell_vmx} #{ova_file}")

  image_file = File.join(dir, 'image')
  puts "image_file: #{image_file}"

  gzip_file(ova_file, image_file)
  image_sha1 = Digest::SHA1.file(image_file).hexdigest
  MFTemplate.new("#{BUILDER_PATH}/erb_templates/vsphere/stemcell.MF.erb", VERSION, sha1: image_sha1).save(dir)

  exec_command("tar czvf #{stemcell_filename} -C #{dir} stemcell.MF image")
  S3Client.new().Put(OUTPUT_BUCKET,File.basename(stemcell_filename),stemcell_filename)
ensure
  puts "removing temp directory: #{dir}"
  if File.exists?(dir)
    FileUtils.remove_entry dir
  end
end
