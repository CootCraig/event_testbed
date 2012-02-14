
require 'rubygems'
require 'bundler/setup'

require 'net/http'
require 'json'
require 'ruby-debug'

if ARGV.length == 0
  puts "usage: test_client URL"
  exit
end
url = ARGV[0]
puts "URL is #{url}"

uri = URI(url)

Net::HTTP.start(uri.host, uri.port) do |http|
  request = Net::HTTP::Get.new uri.request_uri

  http.request request do |response|
    response.read_body do |chunk|
      o = JSON.parse(chunk)
      puts o.to_s
    end
  end
end

