# Examples #

These examples demonstrate the use of the [UBloxM8N and UbxMsgParser libraries](https://github.com/electricimp/UBloxM8N) and the AssistNow Agent and Device Libraries.

## Assist Online and Assist Offline ##

This example uses both the AssistNow Online and AssistNow Offline services to get a fix quickly before putting the device into deep sleep. If you expect your device to be in locations were cellular and/or WiFi connections are poor, the data in the cached AssistNow Offline messages can help get a fix more quickly while your device is offline. AssistNow Offline data is only valid for a limited time, so you will still need to connect regularly and update your AssistNow Offline cache.

- [Agent code](./AssistNowExample.agent.nut)<br>
- [Device code](./AssistNowExample.device.nut)
