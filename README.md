# UBloxAssistNow #

Electric Imp offers two u-blox GNSS Assistance Service libraries, an agent side library that retrieves data from the AssistNow servers, and a device side library that manages delivery of the AssistNow messages to the u-blox M8N. For information about AssistNow services see this [user guide](https://www.u-blox.com/sites/default/files/products/documents/MultiGNSS-Assistance_UserGuide_%28UBX-13004360%29.pdf). For information on u-blox M8N see the [Receiver Description](https://www.u-blox.com/sites/default/files/products/documents/u-blox8-M8_ReceiverDescrProtSpec_%28UBX-13003221%29_Public.pdf).

These libraries work independently and together. Users are responsible for writing code that passes data from the Assist Now web services from the agent to the device.

## Agent Library ##

[Documentation](./AGENT_LIB_README.md)

[Code](./UBloxAssistNow.agent.lib.nut)

**To add this library to your project, add** `#require "UBloxAssistNow.agent.lib.nut:0.1.0"` **to the top of your device code.**

## Device Library ##

[Documentation](./DEVICE_LIB_README.md)

[Code](./UBloxAssistNow.device.lib.nut)

**To add this library to your project, add** `#require "UBloxAssistNow.device.lib.nut:1.0.0"` **to the top of your device code.**

