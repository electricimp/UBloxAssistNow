# UBloxAssistNow #

Device library that manages delivery of the AssistNow messages to the u-blox M8N.

**To add this library to your project, add** `#require "UBloxAssistNow.device.lib.nut:1.0.0"` **to the top of your device code.**

## Class Usage ##

The device-side library for managing Ublox Assist Now messages that help Ublox M8N get a fix faster. This class is dependent on the UBloxM8N and UbxMsgParser libraries. If Assist Offline is used this library also requires Spi Flash File System library.

### Constructor: UBloxAssistNow(*ubx[, sffs]*) ###

Initializes Assist Now library. The constructor will enable ACKs for aiding packets, and register message specific callbacks for MON-VER (0x0a04) and MGA-ACK (0x1360) messages. Users must not register callbacks for these. The latest MON-VER payload is available by calling class method getMonVer. During initialization the protocol version will be checked, and an error thrown if an unsupported version is detected.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *ubx* | UBloxM8N | Yes | A UBloxM8N intance that has been configured to accept and output UBX messages. |
| *sffs* | SPIFlashFileSystem | No | An initialized SPI Flash File system object. This is required if Offline Assist is used. |

## Class Methods ##

### getMonVer() ###

Returns the parsed payload from the last MON-VER message

#### Parameters ####

None

#### Return Value ####

A table.

| Key | Type | Description |
| --- | --- | --- |
| *type* | integer | Type of acknowledgment: 0 = The message was not used by the receiver (see infoCode field for an indication of why), 1 = The message was accepted for use by the receiver (the infoCode field will be 0). |
| *version* | integer | Message version (0x00 for this version). |
| *infoCode* | integer | Provides greater information on what the receiver chose to do with the message contents: 0 = The receiver accepted the data, 1 = The receiver doesn't know the time so can't use the data (To resolve this a UBX-MGA-INITIME_UTC message should be supplied first), 2 = The message version is not supported by the receiver, 3 = The message size does not match the message version, 4 = The message data could not be stored to the database, 5 = The receiver is not ready to use the message data, 6 = The message type is unknown. |
| *msgId* | integer | UBX message ID of the ack'ed message. |
| *msgPayloadStart* | blob | The first 4 bytes of the ack'ed message's payload. |

### updateAssistQueue(*assistMsgs*) ###

Updates assist message queue.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *assistMsgs* | blob | Yes | Takes message blob from Online Assist message from agent or persisted Offline Assist. |

#### Return Value ####

A boolean, if assist queue has any messages.

### startAssistWrite(*[onDone]*) ###

Starts to write assist message queue to Ublox module.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *onDone* | function | No | A callback function that is triggered when all assist messages have been written to the M8N. This function has one parameter *error*, which is null if no errors were encountered when writing messages to the M8N or a array of error tables if an error was encountered. (error table keys: "desc", "payload") |

#### Return Value ####

None.

### getPersistedOfflineAssist() ###

Retrieves Offline Assist messages from storage and returns the messages for today's date. This method will throw an error if the class was not initialized with SPI Flash File System.

#### Parameters ####

None.

#### Return Value ####

Blob, of Offline Assist messages for today's date.

### persistOfflineAssist(*mgaAnoMsgsByFileName*) ###

Stores Offline Assist messages to SPI organized by file name. When messages are stored toggles flag that indicates messages have been refreshed. This method will throw an error if the class was not initialized with SPI Flash File System.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *mgaAnoMsgsByFileName* | table | Yes | The offline assist messages organized by file name. |

#### Return Value ####

None.

### assistOfflineRefreshed() ###

Returns boolean, if Offline Assist messages have been stored since boot.

#### Parameters ####

None.

#### Return Value ####

Bool, if Offline Assist messages have been stored since boot.