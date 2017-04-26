Change Log
==========

### master (unreleased)

* add certificate type to description

### 0.7.5 (2017-04-25)

* Add support for new certificate type (passes)
* Fix rich text (#49)
* Fix app name (#47)
* Update docs pushing to macOS

### 0.7.4 (2017-01-16)

* Add support for handshake error (internal error)
* Add detection of p12 without password

### 0.7.3 (2016-09-19)

* Add support for Watch Kit certificates (DanielFontes)
* Add support for handshake error (certificate unknown)

### 0.7.2 (2016-07-19)

* Added support for Carthage, thanks to @zats

### 0.7.1 (2016-04-27)

* Remove Mac enum from Touch target

### 0.7.0 (2016-01-07)

* Add support for simplified certificates (pull request by 666tos)

### 0.6.4 (2015-12-20)

* Add support for new certificate types (web, simplified, voip)
* Add support for handshake errors (dark wake and closed abort)

### 0.6.3 (2015-01-22)

* Add certificate expiration date to listing
* Add expiration and revocation error message

### 0.6.2 (2015-01-15)

* Add underlying error reason code

### 0.6.1 (2015-01-14)

* Add SSL handshake error codes

### 0.6.0 (2014-10-30)

* Remove kNWSuccess
* Remove deprecated

### 0.5.4 (2014-10-28)

* Deprecate fetching
* Document all framework stuff

### 0.5.3 (2014-10-22)

* Set NWHub defaults to autoConnect:YES
* Add a bunch of helpers to NWHub and NWPusher

### 0.5.2 (2014-10-19)

* Add convenient connect methods
* Introduce Cocoa-style error handling (NSError)
* Deprecate C-style error handling (NWError)
* Cleanup readme examples
* Add troubleshooting in readme

### 0.5.1 (2014-07-26)

* Add OpenSSL readme
* Fix syntax

### 0.4.3 (2014-04-09)

* Add read feedback demo app
* Add log view demo app

### 0.4.2 (2014-03-31)

* Intro new config format Mac app
* Cleanup Mac demo
* Add demo device token history

### 0.4.1 (2014-03-24)

* Fix leaks
* Fix APN error reporting
* Add p12 import to demo

### 0.4.0 (2014-03-23)

* Add detailed error reporting
* Redo readme
* Fix demo
* Redesign API

### 0.3.5 (2014-03-21)

* Support multiple identities
* Add inspect tool
* Fix mem leak
* Fix failed fetch

### 0.3.4 (2014-03-17)

* Tweak demo menu
* Remove iosock, fix ssl connection
* Add support Mac push certs
* Merge pull request #7 from AriX/master

### 0.3.3 (2014-03-03)

* Add support of expiry and priority
* Add support for Apple's third binary format
* Fix ssl connect retry
* Tweak readme, add links
* Merge pull request #5 from ChristianKienle/master
* Fix feedback fetching
* Add helpers to hub and feedback
* Add demo auto-increment payload counter

### 0.3.2 (2014-01-27)

* Cleanup project

### 0.3.1 (2014-01-27)

* Add Podspec
* Auto sandbox detection
* Add NWHub on top of NWPusher
* Lots of demo fixes

### 0.3.0 (2014-01-15)

* Add support for new push format
* Add troubleshooting in readme
* Add reconnect to demo app

### 0.2.0 (2013-04-27)

* Add demo application

### 0.1.0 (2012-09-10)

* First release of the framework
