require 'aws-sdk'

class S3Client
  def initialize()
    @s3 = Aws::S3::Client.new
  end

  def Get(bucket,key,file_name)
    Puts "Downloading the #{key} from #{bucket} to #{file_name}"
    File.open(file_name, 'wb') do |file|
      @s3.get_object({ bucket:bucket , key:key, response_target: file })
    end
    Puts "Finished Downloading the #{key} from #{bucket} to #{file_name}"
  end
  def Put(bucket,key,file_name)
    Puts "Uploading the #{file_name} to #{bucket}:#{key}"
    File.open(file_name, 'rb') do |file|
      @s3.put_object({ bucket:bucket , key:key, body: file })
    end
    Puts "Finished uploading the #{file_name} to #{bucket}:#{key}"
  end
end

abort "AWS_ACCESS_KEY_ID not set" unless ENV.has_key?('AWS_ACCESS_KEY_ID')
abort "AWS_SECRET_ACCESS_KEY not set" unless ENV.has_key?('AWS_SECRET_ACCESS_KEY')
