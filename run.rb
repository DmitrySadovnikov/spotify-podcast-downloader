require "uri"
require "net/http"
require 'base64'
require "json"

ACCOUNT_URL = 'https://accounts.spotify.com'
API_URL = 'https://api.spotify.com/v1'
SCOPES = [
  'user-library-read',
  'playlist-read-private',
  'playlist-modify-public',
  'playlist-modify-private'
]

def process
  @config = JSON.parse(File.read('config.json'))

  puts "Please enter the podcast name: "
  podcast_name = gets.chomp

  puts "Please enter the offline playlist name: "
  offline_playlist_name = gets.chomp

  puts "Please follow the link: #{build_auth_url}"
  puts "Paste the URL you were redirected to:"

  code = gets.chomp.split("code=").last
  puts "Code: #{code}"
  puts "Getting access token"
  access_token_response = request_access_token(code)
  @config["ACCESS_TOKEN"] = access_token_response['access_token']
  puts "Getting podcasts"
  podcasts_response = api_request(url: URI("#{API_URL}/me/shows"))
  podcast = podcasts_response['items'].find { |podcast| podcast['show']['name'] == podcast_name }
  podcast_id = podcast['show']['id']
  puts "Getting podcast episodes"
  episodes_response = api_request(url: URI("#{API_URL}/shows/#{podcast_id}/episodes"))
  uris = episodes_response['items'].map { |episode| episode['uri'] }
  puts "Received #{uris.length} episodes"
  puts "Getting playlists"
  playlists_response = api_request(url: URI("#{API_URL}/me/playlists"))
  offline_playlist = playlists_response['items'].find { |playlist| playlist['name'] == offline_playlist_name }
  playlist_id = offline_playlist['id']
  puts "Adding episodes to offline playlist"
  api_request(
    method: :post,
    url: URI("#{API_URL}/playlists/#{playlist_id}/tracks"),
    body: { uris: uris },
  )
  puts "Episodes added to offline playlist"
end

### AUTHENTICATION
def build_auth_url
  params = {
    response_type: 'code',
    client_id: @config['CLIENT_ID'],
    redirect_uri: @config['REDIRECT_URI'],
    scope: SCOPES.join(' ')
  }
  URI("#{ACCOUNT_URL}/authorize?#{URI.encode_www_form(params)}")
end

def request_access_token(code)
  url = URI("#{ACCOUNT_URL}/api/token")
  https = Net::HTTP.new(url.host, url.port)
  https.use_ssl = true
  request = Net::HTTP::Post.new(url)
  request["Content-Type"] = "application/x-www-form-urlencoded"
  request["Authorization"] = "Basic #{Base64.encode64("#{@config['CLIENT_ID']}:#{@config['CLIENT_SECRET']}").gsub("\n", '')}"
  request.body = URI.encode_www_form(
    {
      grant_type: 'authorization_code',
      code: code,
      redirect_uri: @config['REDIRECT_URI']
    }
  )
  response = https.request(request)
  response_body = response.read_body

  if response.code != '200'
    raise "Error: #{response_body}"
  end
  JSON.parse(response_body)
end

def api_request(url:, method: :get, body: nil)
  https = Net::HTTP.new(url.host, url.port)
  https.use_ssl = true
  request = Net::HTTP.const_get(method.to_s.capitalize).new(url)
  request["Content-Type"] = "application/json"
  request["Authorization"] = "Bearer #{@config["ACCESS_TOKEN"]}"
  request.body = JSON.dump(body) if body
  response = https.request(request)
  response_body = response.read_body
  unless response.code.match? /^20\d$/
    raise "Error: #{response_body}"
  end
  JSON.parse(response_body)
end

process
