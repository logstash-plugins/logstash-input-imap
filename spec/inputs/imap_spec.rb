# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
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

  subject do
    Mail.new do
      from     "me@example.com"
      to       "you@example.com"
      subject  "logstash imap input test"
      date     msg_time
      body     msg_text
      add_file :filename => "some.html", :content => msg_html
    end
  end

  context "with both text and html parts" do
    context "when no content-type selected" do
      it "should select text/plain part" do
        config = {"type" => "imap", "host" => "localhost",
                  "user" => "#{user}", "password" => "#{password}"}

        input = LogStash::Inputs::IMAP.new config
        input.register
        event = input.parse_mail(subject)
        insist { event.get("message") } == msg_text
      end
    end

    context "when text/html content-type selected" do
      it "should select text/html part" do
        config = {"type" => "imap", "host" => "localhost",
                  "user" => "#{user}", "password" => "#{password}",
                  "content_type" => "text/html"}

        input = LogStash::Inputs::IMAP.new config
        input.register
        event = input.parse_mail(subject)
        insist { event.get("message") } == msg_html
      end
    end
  end

  context "when subject is in RFC 2047 encoded-word format" do
    it "should be decoded" do
      subject.subject = "=?iso-8859-1?Q?foo_:_bar?="
      config = {"type" => "imap", "host" => "localhost",
                "user" => "#{user}", "password" => "#{password}"}

      input = LogStash::Inputs::IMAP.new config
      input.register
      event = input.parse_mail(subject)
      insist { event.get("subject") } == "foo : bar"
    end
  end

  context "with multiple values for same header" do
    it "should add 2 values as array in event" do
      subject.received = "test1"
      subject.received = "test2"

      config = {"type" => "imap", "host" => "localhost",
                "user" => "#{user}", "password" => "#{password}"}

      input = LogStash::Inputs::IMAP.new config
      input.register
      event = input.parse_mail(subject)
      insist { event.get("received") } == ["test1", "test2"]
    end

    it "should add more than 2 values as array in event" do
      subject.received = "test1"
      subject.received = "test2"
      subject.received = "test3"

      config = {"type" => "imap", "host" => "localhost",
                "user" => "#{user}", "password" => "#{password}"}

      input = LogStash::Inputs::IMAP.new config
      input.register
      event = input.parse_mail(subject)
      insist { event.get("received") } == ["test1", "test2", "test3"]
    end
  end

  context "when a header field is nil" do
    it "should parse mail" do
      subject.header['X-Custom-Header'] = nil
      config = {"type" => "imap", "host" => "localhost",
                "user" => "#{user}", "password" => "#{password}"}

      input = LogStash::Inputs::IMAP.new config
      input.register
      event = input.parse_mail(subject)
      insist { event.get("message") } == msg_text
    end
  end

  context "when mail_in_attachment selected" do
    it "should parse attachment as the actual mail" do
      # Some servers forward mail as an attachment in an encapsulating mail.
      # As an example, the server PowerMTA, delivers unmatched bounce messages,
      # in a base64 encoded attachment, named "email.txt".
      encapsulating_mail = Mail.new do
        from     "mta@example.com"
        to       "unmatched@example.com"
        subject  "MTA unmatched message test"
        date     Time.new
        body     "The MTA could not recognize the attached message test"
      end
      encapsulating_mail.attachments['email.txt'] = {
        :mime_type => 'text/plain', :content_transfer_encoding => 'base64',
        :content => Base64.encode64(subject.to_s)
      }
      config = {"type" => "imap", "host" => "localhost",
                "user" => "#{user}", "password" => "#{password}",
                "mail_in_attachment" => "true"}

      input = LogStash::Inputs::IMAP.new config
      input.register
      event = input.parse_mail(encapsulating_mail)
      insist { event.get("message") } == msg_text
    end
  end
end
