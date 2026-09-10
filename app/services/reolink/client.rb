require "net/http"

module ReoLink
  # Talks to a ReoLink camera's built-in HTTP CGI API to pull a still-image
  # snapshot. Connection details are read from ENV (see .env.example) rather
  # than stored in the database, matching how VAPID keys are configured
  # elsewhere in this app.
  #
  #   ReoLink::Client.new.snapshot # => [binary_jpeg_data, "image/jpeg"]
  class Client
    class Error < StandardError; end

    DEFAULT_CHANNEL = "0"
    DEFAULT_SCHEME  = "http"
    OPEN_TIMEOUT    = 5
    READ_TIMEOUT    = 8

    def self.configured?
      ENV["REOLINK_HOST"].present?
    end

    def initialize(host: ENV["REOLINK_HOST"], username: ENV["REOLINK_USERNAME"],
                   password: ENV["REOLINK_PASSWORD"], channel: ENV["REOLINK_CHANNEL"].presence || DEFAULT_CHANNEL,
                   scheme: ENV["REOLINK_SCHEME"].presence || DEFAULT_SCHEME)
      raise Error, "REOLINK_HOST is not configured"     if host.blank?
      raise Error, "REOLINK_USERNAME is not configured" if username.blank?
      raise Error, "REOLINK_PASSWORD is not configured" if password.blank?

      @host     = host
      @username = username
      @password = password
      @channel  = channel
      @scheme   = scheme
    end

    # Fetches a still-image snapshot from the camera.
    #
    # Returns [binary_body, content_type].
    # Raises ReoLink::Client::Error on any failure (timeout, network error,
    # non-2xx response, empty body).
    def snapshot
      uri      = snapshot_uri
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                       open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "Unexpected response from camera: #{response.code} #{response.message}"
      end
      raise Error, "Camera returned an empty snapshot body" if response.body.blank?

      [ response.body, response.content_type.presence || "image/jpeg" ]
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise Error, "Timed out contacting camera at #{@host}: #{e.message}"
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT => e
      raise Error, "Could not reach camera at #{@host}: #{e.message}"
    end

    private

    # NOTE: ReoLink's CGI API takes the camera password as a plain query
    # parameter — there's no token/session exchange to avoid it. Set
    # REOLINK_SCHEME=https if your camera's firmware exposes an HTTPS
    # listener on its CGI port; over plain HTTP (the default, and the only
    # option most ReoLink camera firmwares actually support) the password is
    # only as safe as the local network it travels over.
    def snapshot_uri
      params = {
        cmd:      "Snap",
        channel:  @channel,
        rs:       SecureRandom.hex(6),
        user:     @username,
        password: @password
      }

      URI("#{@scheme}://#{@host}/cgi-bin/api.cgi").tap { |uri| uri.query = URI.encode_www_form(params) }
    end
  end
end
