# Examples #

These examples show how to use the UBloxM8N driver, UbxMsgParser and the AssistNow Agent and Device Libraries. The agent code for both examples is the same.

## Assist Online Only ##

This example uses the assist now online messages to get a fix quickly before going into deep sleep. If you expect your device to be in locations were connections and GPS reception are good the Online Asssist can help get a fix more quickly.

[Link to agent code](./assistExample.agent.nut)
[Link to device code](./assistOnlineOnly.device.nut)

## Assist Online and Assist Offline ##

This example uses both the assist now online and assist now offline messages to get a fix quickly before going into deep sleep. If you expect your device to be in locations were connections and GPS reception will be poor the offline assist can help estimate location more quickly.

[Link to agent code](./assistExample.agent.nut)
[Link to device code](./assistOnlineAndOffline.device.nut)
