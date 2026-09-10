require "rails_helper"

RSpec.describe ReoLink::Client do
  let(:host)     { "10.27.140.51" }
  let(:username) { "admin" }
  let(:password) { "this4you" }
  let(:image_body) { File.binread(Rails.root.join("spec/fixtures/files/snapshot.jpg")) }

  describe ".configured?" do
    it "is true when REOLINK_HOST is present" do
      stub_const("ENV", ENV.to_hash.merge("REOLINK_HOST" => host))
      expect(described_class.configured?).to be true
    end

    it "is false when REOLINK_HOST is blank" do
      stub_const("ENV", ENV.to_hash.merge("REOLINK_HOST" => nil))
      expect(described_class.configured?).to be false
    end
  end

  describe "#initialize" do
    it "raises when host is missing" do
      expect { described_class.new(host: nil, username: username, password: password) }
        .to raise_error(ReoLink::Client::Error, /REOLINK_HOST/)
    end

    it "raises when username is missing" do
      expect { described_class.new(host: host, username: nil, password: password) }
        .to raise_error(ReoLink::Client::Error, /REOLINK_USERNAME/)
    end

    it "raises when password is missing" do
      expect { described_class.new(host: host, username: username, password: nil) }
        .to raise_error(ReoLink::Client::Error, /REOLINK_PASSWORD/)
    end
  end

  describe "#snapshot" do
    subject(:client) { described_class.new(host: host, username: username, password: password, channel: 0) }

    it "issues a GET request to the camera's Snap CGI endpoint" do
      stub = stub_request(:get, %r{\Ahttp://10\.27\.140\.51/cgi-bin/api\.cgi})
        .with(query: hash_including("cmd" => "Snap", "channel" => "0", "user" => username, "password" => password))
        .to_return(status: 200, body: image_body, headers: { "Content-Type" => "image/jpeg" })

      client.snapshot

      expect(stub).to have_been_requested
    end

    it "returns the binary body and content type" do
      stub_request(:get, %r{\Ahttp://10\.27\.140\.51/cgi-bin/api\.cgi})
        .to_return(status: 200, body: image_body, headers: { "Content-Type" => "image/jpeg" })

      body, content_type = client.snapshot

      expect(body).to eq(image_body)
      expect(content_type).to eq("image/jpeg")
    end

    it "defaults the content type when the camera does not send one" do
      stub_request(:get, %r{\Ahttp://10\.27\.140\.51/cgi-bin/api\.cgi})
        .to_return(status: 200, body: image_body)

      _body, content_type = client.snapshot

      expect(content_type).to eq("image/jpeg")
    end

    it "raises on a non-2xx response" do
      stub_request(:get, %r{\Ahttp://10\.27\.140\.51/cgi-bin/api\.cgi})
        .to_return(status: 401, body: "Unauthorized")

      expect { client.snapshot }.to raise_error(ReoLink::Client::Error, /Unexpected response/)
    end

    it "raises on an empty body" do
      stub_request(:get, %r{\Ahttp://10\.27\.140\.51/cgi-bin/api\.cgi})
        .to_return(status: 200, body: "")

      expect { client.snapshot }.to raise_error(ReoLink::Client::Error, /empty snapshot/)
    end

    it "raises a ReoLink::Client::Error on a connection timeout" do
      stub_request(:get, %r{\Ahttp://10\.27\.140\.51/cgi-bin/api\.cgi}).to_timeout

      expect { client.snapshot }.to raise_error(ReoLink::Client::Error, /Timed out/)
    end

    it "raises a ReoLink::Client::Error when the camera is unreachable" do
      stub_request(:get, %r{\Ahttp://10\.27\.140\.51/cgi-bin/api\.cgi})
        .to_raise(SocketError.new("getaddrinfo: nodename nor servname provided"))

      expect { client.snapshot }.to raise_error(ReoLink::Client::Error, /Could not reach camera/)
    end
  end
end
