require 'aws-sdk'

class S3Client
  def initialize()
    @s3 = Aws::S3::Client.new
  end

  def Get(bucket,key,dest_name)
    Puts "Downloading the #{key} from #{bucket} to #{dest_name}"
    File.open(dest_name, 'wb') do |file|
      @s3.get_object({ bucket:bucket , key:key, response_target: file })
    end
    Puts "Finished Downloading the #{key} from #{bucket} to #{dest_name}"
  end
end

abort "AWS_ACCESS_KEY_ID not set" unless ENV.has_key?('AWS_ACCESS_KEY_ID')
abort "AWS_SECRET_ACCESS_KEY not set" unless ENV.has_key?('AWS_SECRET_ACCESS_KEY')

