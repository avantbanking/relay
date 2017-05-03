# Relay: A remote logger for [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack).
![Platforms](https://img.shields.io/badge/platforms-ios%20-lightgrey.svg)
![Languages](https://img.shields.io/badge/languages-swift%203-orange.svg)
![License](https://img.shields.io/badge/license-MIT%2FApache-blue.svg)
[![Build Status](https://travis-ci.org/zerofinancial/relay.svg?branch=master)](https://travis-ci.org/zerofinancial/relay)
[![Coverage Status](https://coveralls.io/repos/github/Zerofinancial/relay/badge.svg)](https://coveralls.io/github/Zerofinancial/relay)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Twitter](https://img.shields.io/badge/twitter-@zerofinancial-blue.svg?style=flat)](http://twitter.com/zerofinancial)


### [See the docs](https://zerofinancial.github.io/relay/)


Monitoring fatal crash rates are essential - especially on iOS where submitting a critical bug fix
is at the mercy of the app review team - but what about nonfatals that prevent or hamper your user's experience? Relay makes it easy to send logs to [Logstash](https://www.elastic.co/products/logstash), [Graylog](https://www.graylog.org), [Splunk](https://splunk.com), and other log aggregators. Designed around unreliable mobile connections, Relay leverages `URLSessionUploadTask`s to pass log data to the system process ASAP so you don't need to cross your fingers and hope the log uploads before the app is suspended. Pending log uploads are persisted across system reboots, and have a default retry behavior to ensure log data gets successfully sent.

## Installation

### Dependencies

- Given this is a logger for CocoaLumberjack, CocaLumberjack is required.
- [Realm](https://github.com/realm/realm-cocoa) is used to maintain the log records created from each `DDLogMessage` passsed from CocoaLumberjack.
  Each created `Relay` maintains it's own SQLite database located in the Documents folder on iOS.

### Carthage
Add the following to your Cartfile:

```
github zerofinancial.com/relay ~> 0.0.0
```

Be sure to add `Relay` and `Realm` to your Carthage run script.

### Manually
Download the latest framework binary off the releases page, and [Realm](https://github.com/realm/realm-cocoa). Add them to your project, set the proper framework search paths, and you're ready to go.

## Configuration
Take a look at the [documentation](https://zerofinancial.github.io/relay/) for all configurable options.

## License
Relay is licensed under either of
 * Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
   http://www.apache.org/licenses/LICENSE-2.0)
 * MIT license ([LICENSE-MIT](LICENSE-MIT) or
   http://opensource.org/licenses/MIT).

### Contribution
Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you shall be dual licensed as above, without any additional terms or conditions.

## About

<img src="https://github.com/zerofinancial/relay/blob/master/images/zeroLogo.jpg?raw=true" width="119.5" height="33.5" />

Relay is maintained by Zero by Evan Kimia. The names and logos for Zero and Relay are trademarks of Zero Financial Inc.
Follow our [blog](https://zerofinancial.com/blog) or say hi on twitter [@zerofinancial](https://twitter.com/zerofinancial).
