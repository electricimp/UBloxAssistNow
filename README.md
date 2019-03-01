# UBloxAssistNow #

Electric Imp offers two u-blox GNSS Assistance Service libraries: an agent-side library that retrieves data from the AssistNow servers, and a device-side library that manages delivery of the AssistNow messages to the [u-blox M8N GPS module](https://www.u-blox.com/en/product/neo-m8-series). 

- For more information about AssistNow services, please see [this user guide on the u-blox website](https://www.u-blox.com/sites/default/files/products/documents/MultiGNSS-Assistance_UserGuide_%28UBX-13004360%29.pdf).

- For more information on the u-blox M8N module, please see [the receiver description on the u-blox website](https://www.u-blox.com/sites/default/files/products/documents/u-blox8-M8_ReceiverDescrProtSpec_%28UBX-13003221%29_Public.pdf).

These libraries work independently and together. Users are responsible for writing code that passes data from the AssistNow web service from the agent to the device.

## Agent Library ##

- [Documentation](./AgentLibrary/README.md)
- [Source code](./AgentLibrary/UBloxAssistNow.agent.lib.nut)

**To include this library in your project, add** `#require "UBloxAssistNow.agent.lib.nut:1.0.0"` **at the top of your agent code.**

## Device Library ##

- [Documentation](./DeviceLibrary/README.md)
- [Source code](./AgentLibrary/UBloxAssistNow.device.lib.nut)

**To include this library in your project, add** `#require "UBloxAssistNow.device.lib.nut:0.1.0"` **at the top of your device code.**

## Examples ##

- [Summary](./Examples/README.md)
- [Examples](./Examples)

## License ##

These libraries are licensed under the [MIT License](./LICENSE).