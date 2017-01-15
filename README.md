# Relay: A remote logger for [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack).
![Platforms](https://img.shields.io/badge/platforms-ios%20%7C%20osx%20%7C%20watchos%20%7C%20tvos-lightgrey.svg)
![Languages](https://img.shields.io/badge/languages-swift%203-orange.svg)
![License](https://img.shields.io/badge/license-MIT%2FApache-blue.svg)
[![Build Status](https://travis-ci.org/Zerofinancial/relay.svg?branch=master)](https://travis-ci.org/Zerofinancial/relay)
[![Coverage Status](https://coveralls.io/repos/github/Zerofinancial/relay/badge.svg)](https://coveralls.io/github/Zerofinancial/relay)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
 [![Twitter](https://img.shields.io/badge/twitter-@zerofinancial-blue.svg?style=flat)](http://twitter.com/zerofinancial)

===

## [Documentation](https://zerofinancial.github.io/relay/)

===

Fatal crash rates are essential to monitor for compiled applications, especially on iOS where submitting a criticial bug fix
is at the mercy of the app review team, but what about nonfatals that prevent or hamper your user's experience? Relay makes it easy to send logs to [Logstash](https://www.elastic.co/products/logstash), [Graylog](https://www.graylog.org), [Splunk](https://splunk.com), and other log aggregators. Designed around unreliable mobile connections, Relay leverages URLSessionUploadTasks to pass log data to the system process asap so you dont need to cross your fingers and hope the log uploads before the app is suspended. Pending log uploads are persisted across system reboots, and have a default retry behavior to ensure log data gets successfully sent.

## Installation

### Carthage
Add the following to your Cartfile:

```
github zerofinancial.com/relay ~> 1.0
```

### Manually
Download the framework file off the releases page and add to your project

## Configuration
Take a look at the [documentation](https://zerofinancial.github.io/relay/) for all configurable options.

## License
Relay is licensed under either of
 * Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
   http://www.apache.org/licenses/LICENSE-2.0)
 * MIT license ([LICENSE-MIT](LICENSE-MIT) or
   http://opensource.org/licenses/MIT) at your option.

### Contribution
Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you shall be dual licensed as above, without any additional terms or conditions.

## About

<img src="images/zeroLogo.jpg" width="119.5" height="33.5" />

Relay is maintained by Zero. The names and logos for Zero and Relay are trademarks of Zero Financial Inc.
Follow our [blog](https://zerofinancial.com/blog) or say hi on twitter [@zerofinancial](https://twitter.com/zerofinancial)
