# Spotify Podcast Downloader

A simple script to move all episodes of a selected podcast to a playlist, which can then be downloaded to your device with a premium subscription.

## Installation

1. Subscribe to the podcast you want to download.
2. Create a playlist and select "Download".
3. Create a new app on the Spotify Developer Dashboard.
4. Add the Client ID, Client Secret, and Redirect URI to the `config.json` file. The Redirect URI can be anything, for example, `https://google.com`.
5. Run the script:
   ```bash
   ruby run.rb
   ```

   The script will prompt you to enter the podcast name and the playlist name. It will also ask you to authenticate with your Spotify account and then redirect to the specified Redirect URI with a code. Copy the code or full URL and paste it into the terminal.

6. The script will move all episodes of the podcast to the playlist. You can now download the playlist to your device.
