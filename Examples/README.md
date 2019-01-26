# Examples #

These examples show how to use the UBloxM8N driver, UbxMsgParser and the AssistNow Agent and Device Libraries.

## Assist Online Only ##

This example uses AssistNow Online messages to get a fix quickly before going into deep sleep.

[Link to agent code](./assistOnlineOnly.agent.nut)<br>
[Link to device code](./assistOnlineOnly.device.nut)

## Assist Online and Assist Offline ##

This example uses both the AssistNow Online and AssistNow Offline messages to get a fix quickly before going into deep sleep. If you expect your device to be in locations were cellular/WiFi connections are poor the data in the cached AssistNow Offline messages can help get a fix more quickly while your device is offline. AssistNow Offline data is only valid for a limited time, so you will still need to connect and update AssistNow Offline cache.

[Link to agent code](./assistOnlineAndOffline.agent.nut)<br>
[Link to device code](./assistOnlineAndOffline.device.nut)
