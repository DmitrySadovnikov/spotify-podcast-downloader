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

  code = get_code
  puts "Code: #{code}"
  puts "Getting access token"
  access_token_response = get_access_token(code)
  access_token = access_token_response['access_token']

  puts "Access token: #{access_token}"
  puts "Getting podcasts"
  podcasts_response = get_podcasts(access_token)
  podcast = podcasts_response['items'].find { |podcast| podcast['show']['name'] == podcast_name }

  podcast_id = podcast['show']['id']
  puts "Podcast name: #{podcast_name}"
  puts "Podcast id: #{podcast_id}"
  puts "Getting podcast episodes"
  episodes_response = get_podcast_episodes(access_token, podcast_id)
  episode_uris = episodes_response['items'].map { |episode| episode['uri'] }
  puts "Received #{episode_uris.length} episodes"
  puts "Getting playlists"
  playlists_response = get_playlists(access_token)
  offline_playlist = playlists_response['items'].find { |playlist| playlist['name'] == offline_playlist_name }
  offline_playlist_id = offline_playlist['id']
  puts "Offline playlist name: #{offline_playlist_name}"
  puts "Offline playlist id: #{offline_playlist_id}"
  puts "Adding episodes to offline playlist"
  add_episodes_to_offline_playlist(episode_uris, offline_playlist_id, access_token)
  puts "Episodes added to offline playlist"
end

### AUTHENTICATION START
def get_code
  params = {
    client_id: @config['CLIENT_ID'],
    response_type: 'code',
    redirect_uri: @config['REDIRECT_URI'],
    scope: SCOPES.join(' ')
  }
  url = URI("#{ACCOUNT_URL}/authorize?#{URI.encode_www_form(params)}")
  puts "please visit: #{url}"
  puts "please enter the URL: "
  gets.chomp.split("code=").last
end

def get_access_token(code)
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
### AUTHENTICATION END

def get_podcasts(access_token)
  url = URI("#{API_URL}/me/shows")
  https = Net::HTTP.new(url.host, url.port)
  https.use_ssl = true

  request = Net::HTTP::Get.new(url)
  request["Authorization"] = "Bearer #{access_token}"
  response = https.request(request)
  response_body = response.read_body
  if response.code != '200'
    raise "Error: #{response_body}"
  end
  JSON.parse(response_body)
end

def get_podcast_episodes(access_token, podcast_id)
  url = URI("#{API_URL}/shows/#{podcast_id}/episodes")

  https = Net::HTTP.new(url.host, url.port)
  https.use_ssl = true

  request = Net::HTTP::Get.new(url)
  request["Authorization"] = "Bearer #{access_token}"

  response = https.request(request)
  response_body = response.read_body
  if response.code != '200'
    raise "Error: #{response_body}"
  end
  JSON.parse(response_body)
end

def get_playlists(access_token)
  url = URI("#{API_URL}/me/playlists")
  https = Net::HTTP.new(url.host, url.port)
  https.use_ssl = true
  request = Net::HTTP::Get.new(url)
  request["Authorization"] = "Bearer #{access_token}"
  response = https.request(request)
  response_body = response.read_body
  if response.code != '200'
    raise "Error: #{response_body}"
  end
  JSON.parse(response_body)
end

def add_episodes_to_offline_playlist(uris, playlist_id, access_token)
  url = URI("#{API_URL}/playlists/#{playlist_id}/tracks")

  https = Net::HTTP.new(url.host, url.port)
  https.use_ssl = true

  request = Net::HTTP::Post.new(url)
  request["Content-Type"] = "application/json"
  request["Authorization"] = "Bearer #{access_token}"
  request.body = JSON.dump({
    uris: uris
  })
  response = https.request(request)
  response_body = response.read_body
  if response.code != '201'
    raise "Error: #{response_body}"
  end
  JSON.parse(response_body)
end

process
