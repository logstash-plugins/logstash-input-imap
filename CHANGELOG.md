## 3.2.0
  - Feat: ECS compatibility [#55](https://github.com/logstash-plugins/logstash-input-imap/pull/55)
    * added (optional) `headers_target` configuration option
    * added (optional) `attachments_target` configuration option
  - Fix: plugin should not close `$stdin`, while being stopped 

## 3.1.0
  - Adds an option to recursively search the message parts for attachment and inline attachment filenames. If the save_attachments option is set to true, the content of attachments is included in the `attachments.data` field. The attachment data can then be used by the Elasticsearch Ingest Attachment Processor Plugin.
  [#48](https://github.com/logstash-plugins/logstash-input-imap/pull/48)

## 3.0.7
  - Added facility to use IMAP uid to retrieve new mails instead of "NOT SEEN" [#36](https://github.com/logstash-plugins/logstash-input-imap/pull/36)

## 3.0.6
  - Docs: Set the default_codec doc attribute.

## 3.0.5
  - Update gemspec summary

## 3.0.4
  - Fix some documentation issues

## 3.0.2
  - Relax constraint on logstash-core-plugin-api to >= 1.60 <= 2.99

## 3.0.1
  - Republish all the gems under jruby.
## 3.0.0
  - Update the plugin to the version 2.0 of the plugin api, this change is required for Logstash 5.0 compatibility. See https://github.com/elastic/logstash/issues/5141
# 2.0.5
  - Depend on logstash-core-plugin-api instead of logstash-core, removing the need to mass update plugins on major releases of logstash
# 2.0.4
  - New dependency requirements for logstash-core for the 5.0 release
## 2.0.3
 - Fixed fields assignments

## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully,
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0

