# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/inputs/imap"
require "mail"
require "net/imap"


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

  subject do
    Mail.new do
      from     "me@example.com"
      to       "you@example.com"
      subject  "logstash imap input test"
      date     msg_time
      body     msg_text
      add_file :filename => "some.html", :content => msg_html
      add_file :filename => "image.png", :content => msg_binary
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

  context "with attachments" do
    it "should extract filenames" do
      config = {"type" => "imap", "host" => "localhost",
                "user" => "#{user}", "password" => "#{password}"}

      input = LogStash::Inputs::IMAP.new config
      input.register
      event = input.parse_mail(subject)
      insist { event.get("attachments") } == [{"filename"=>"some.html"}, {"filename"=>"image.png"}]
    end

    it "should extract the base64 content" do
      config = {"type" => "imap", "host" => "localhost",
        "user" => "#{user}", "password" => "#{password}",
        "save_attachments" => true}

      input = LogStash::Inputs::IMAP.new config
      input.register
      event = input.parse_mail(subject)
      insist { event.get("attachments") } == [{"data"=>"PHA+YSBwYXJhZ3JhcGg8L3A+Cgo=\r\n", "filename"=>"some.html"}, {"data"=>"QkNE\r\n", "filename"=>"image.png"}]
      end
  end
end