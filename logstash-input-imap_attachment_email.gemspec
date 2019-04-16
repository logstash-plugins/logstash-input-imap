Gem::Specification.new do |s|

  s.name            = 'logstash-input-imap_attachment_email'
  s.version         = '0.1.0'
  s.licenses        = ['Apache License (2.0)']
  s.summary         = "Reads mail from an IMAP server and optionally parses it's attachment as an email"
  s.description     = "This is a simple addition to logstash-input-imap adding the option to parse an attachment as the actual email. This gem is a Logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/logstash-plugin install gemname. This gem is not a stand-alone program"
  s.authors         = ["Elastic", "Rulecom"]
  s.email           = ["info@elastic.co", "info@rule.se"]
  s.homepage        = "https://github.com/rulecom/logstash-input-imap"
  s.require_paths = ["lib"]

  # Files
  s.files = Dir["lib/**/*","spec/**/*","*.gemspec","*.md","CONTRIBUTORS","Gemfile","LICENSE","NOTICE.TXT", "vendor/jar-dependencies/**/*.jar", "vendor/jar-dependencies/**/*.rb", "VERSION", "docs/**/*"]

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "input" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", ">= 1.60", "<= 2.99"
  s.add_runtime_dependency 'logstash-codec-plain'
  s.add_runtime_dependency 'mail', '~> 2.6.3'
  s.add_runtime_dependency 'mime-types', '2.6.2'
  s.add_runtime_dependency 'stud', '~> 0.0.22'

  s.add_development_dependency 'logstash-devutils'
end
