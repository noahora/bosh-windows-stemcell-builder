#!/usr/bin/env ruby

require_relative 'exec-command'
require 'fileutils'

Dir.chdir "stemcell-builder" do
  exec_command("bundle install")
  exec_command("rake build:gcp")
  exec_command("mv bosh-windows-stemcell/*.tgz ../bosh-windows-stemcell")
end
