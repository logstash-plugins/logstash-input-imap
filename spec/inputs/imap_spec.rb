# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/devutils/rspec/shared_examples"
require "logstash/inputs/imap"
require "mail"
require "net/imap"
require "base64"

describe LogStash::Inputs::IMAP do

  context "when interrupting the plugin" do
    it_behaves_like "an interruptible input plugin" do
      let(:config) do
        { "type" => "imap",
          "host" => "localhost",
          "user" => "logstash",
          "password" => "secret" }
      end
      let(:imap) { double("imap") }
      let(:ids)  { double("ids") }
      before(:each) do
        allow(imap).to receive(:login)
        allow(imap).to receive(:select)
        allow(imap).to receive(:close)
        allow(imap).to receive(:disconnect)
        allow(imap).to receive(:store)
        allow(ids).to receive(:each_slice).and_return([])

        allow(imap).to receive(:uid_search).with("NOT SEEN").and_return(ids)
        allow(Net::IMAP).to receive(:new).and_return(imap)
      end
    end
  end

end

describe LogStash::Inputs::IMAP do
  user = "logstash"
  password = "secret"
  msg_time = Time.new
  msg_text = "foo\nbar\nbaz"
  msg_html = "<p>a paragraph</p>\n\n"
  msg_binary = "\x42\x43\x44"
  msg_unencoded = "raw text 🐐"

  let(:config) do
    { "host" => "localhost", "user" => "#{user}", "password" => "#{password}" }
  end

  subject(:input) do
    LogStash::Inputs::IMAP.new config
  end

  let(:mail) do
    Mail.new do
      from     "me@example.com"
      to       "you@example.com"
      subject  "logstash imap input test"
      date     msg_time
      body     msg_text
      message_id '<123@message.id>' # 'Message-ID' header
      # let's have some headers:
      header['X-Priority'] = '3'
      header['X-Bot-ID'] = '111'
      header['X-AES-Category'] = 'LEGIT'
      header['X-Spam-Category'] = 'LEGIT'
      header['Spam-Stopper-Id'] = '464bbb1a-1b86-4006-8a09-ce797fb56346'
      header['Spam-Stopper-v2'] = 'Yes'
      header['X-Mailer'] = 'Microsoft Outlook Express 6.00.2800.1106'
      header['X-MimeOLE'] = 'Produced By Microsoft MimeOLE V6.00.2800.1106'
      add_file :filename => "some.html", :content => msg_html
      add_file :filename => "image.png", :content => msg_binary
      add_file :filename => "unencoded.data", :content => msg_unencoded, :content_transfer_encoding => "7bit"
    end
  end

  before do
    input.register
  end

  context "when no content-type selected" do
    it "should select text/plain part" do
      event = input.parse_mail(mail)
      expect( event.get("message") ).to eql msg_text
    end
  end

  context "when text/html content-type selected" do
    let(:config) { super().merge("content_type" => "text/html") }

    it "should select text/html part" do
      event = input.parse_mail(mail)
      expect( event.get("message") ).to eql msg_html
    end
  end

  context "mail headers" do
    let(:config) { super().merge("lowercase_headers" => true) } # default

    before { @event = input.parse_mail(mail) }

    it "sets all header fields" do
      expect( @event.get("x-spam-category") ).to eql 'LEGIT'
      expect( @event.get("x-aes-category") ).to eql 'LEGIT'
      expect( @event.get("x-bot-id") ).to eql '111'
      ['spam-stopper-id', 'spam-stopper-v2', 'x-mimeole', 'message-id', 'x-priority'].each do |name|
        expect( @event.include?(name) ).to be true
      end
      expect( @event.get("from") ).to eql 'me@example.com'
      expect( @event.get("to") ).to eql 'you@example.com'
      expect( @event.get("subject") ).to eql 'logstash imap input test'
    end

    it 'does not set date header' do
      expect( @event.include?('date') ).to be false
      expect( @event.include?('Date') ).to be false
    end
  end

  context "mail headers (not lower-cased)" do
    let(:config) { super().merge("lowercase_headers" => false) }

    before { @event = input.parse_mail(mail) }

    it "sets all header fields" do
      expect( @event.get("X-Spam-Category") ).to eql 'LEGIT'
      expect( @event.get("X-AES-Category") ).to eql 'LEGIT'
      expect( @event.get("X-Bot-ID") ).to eql '111'
      ['Spam-Stopper-Id', 'Spam-Stopper-v2', 'X-MimeOLE', 'Message-ID', 'X-Priority'].each do |name|
        expect( @event.include?(name) ).to be true
      end
      expect( @event.get("From") ).to eql 'me@example.com'
      expect( @event.get("To") ).to eql 'you@example.com'
      expect( @event.get("Subject") ).to eql 'logstash imap input test'
    end

    it 'does not set date header' do
      expect( @event.include?('Date') ).to be false
    end
  end

  context "when subject is in RFC 2047 encoded-word format" do
    before do
      mail.subject = "=?iso-8859-1?Q?foo_:_bar?="
    end

    it "should be decoded" do
      event = input.parse_mail(mail)
      expect( event.get("subject") ).to eql "foo : bar"
    end
  end

  context "with multiple values for same header" do
    it "should add 2 values as array in event" do
      mail.received = "test1"
      mail.received = "test2"

      event = input.parse_mail(mail)
      expect( event.get("received") ).to eql ["test1", "test2"]
    end

    it "should add more than 2 values as array in event" do
      mail.received = "test1"
      mail.received = "test2"
      mail.received = "test3"

      event = input.parse_mail(mail)
      expect( event.get("received") ).to eql ["test1", "test2", "test3"]
    end
  end

  context "when a header field is nil" do
    it "should parse mail" do
      mail.header['X-Custom-Header'] = nil

      event = input.parse_mail(mail)
      expect( event.get("message") ).to eql msg_text
    end
  end

  context "attachments" do
    it "should extract filenames" do
      event = input.parse_mail(mail)
      expect( event.get("attachments") ).to eql [
        {"filename"=>"some.html"},
        {"filename"=>"image.png"},
        {"filename"=>"unencoded.data"}
      ]
    end
  end

  context "with attachments saving" do
    let(:config) { super().merge("save_attachments" => true) }

    it "should extract the encoded content" do
      event = input.parse_mail(mail)
      expect( event.get("attachments") ).to eql [
                                                    {"data"=> Base64.encode64(msg_html).encode(crlf_newline: true), "filename"=>"some.html"},
                                                    {"data"=> Base64.encode64(msg_binary).encode(crlf_newline: true), "filename"=>"image.png"},
                                                    {"data"=> msg_unencoded, "filename"=>"unencoded.data"}
                                                ]
    end
  end
end
