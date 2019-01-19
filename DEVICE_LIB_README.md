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
| *error* | string/null | Error message if parsing error was encountered or `null`. |
| *payload* | blob | The unparsed payload. |

### setCurrent(*assistMsgs*) ###

Takes a blob of binary messages, splits them into individual messages that are then stored in the currrent message queue, ready to be written to the u-blox module when sendCurrent method is called.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *assistMsgs* | blob | Yes | Takes blob of messages from AssistNow Online web request or the persisted AssistNow Offline messages for today's date. |

#### Return Value ####

A boolean, if there are any current messages to be sent.

### sendCurrent(*[onDone]*) ###

Begins the loop that writes the current assist message queue to u-blox module.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *onDone* | function | No | A callback function that is triggered when all assist messages have been written to the M8N. This function has one parameter *error*, which is null if no errors were encountered when writing messages to the M8N or a array of error tables if an error was encountered. (error table keys: "desc", "payload") |

#### Return Value ####

None.

### persistOfflineMsgs(*msgsByFileName*) ###

Stores Offline Assist messages to SPI organized by file name. When messages are stored toggles flag that indicates messages have been refreshed. This method will throw an error if the class was not initialized with SPI Flash File System.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *msgsByFileName* | table | Yes | table of messages from Offline Assist Web service. Table slots should be file name (i.e. a date string) and values should be string or blob of all the MGA-ANO messages that correspond to that file name. |

#### Return Value ####

None.

### getPersistedFile(*fileName*) ###

Retrieves file from SPI Flash File System (sffs). This method will throw an error if the class was not initialized with SPI Flash File System.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *fileName* | string | Yes | Name of the file to be returned. |

#### Return Value ####

Blob, the binary file from SPI or `null` if no file with that name is stored.

### assistOfflineRefreshed() ###

Returns boolean, if Offline Assist messages have been stored since boot.

#### Parameters ####

None.

#### Return Value ####

Bool, if Offline Assist messages have been stored since boot.

### getDateString() ###

Uses the imp API date method to create a date string formatted YYYYMMDD. This is the same date formatter used by default in the UBloxAssistNow agent library.

#### Parameters ####

None.

#### Return Value ####

String, date fromatted YYYYMMDD.