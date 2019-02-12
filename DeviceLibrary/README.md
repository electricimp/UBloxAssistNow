# UBloxAssistNow #

Device library that manages delivery of the AssistNow messages to the u-blox M8N.

**To add this library to your project, add** `#require "UBloxAssistNow.device.lib.nut:0.1.0"` **to the top of your device code.**

## Class Usage ##

This device-side library is for managing the writing of u-blox Assist Now messages to the u-blox M8N. Assist Now messages help Ublox M8N get a GPS fix faster. This class is dependent on the UBloxM8N library. If this library is included, message callbacks cannot be registered for MGA-ACK (0x1360) and MON-VER (0x0a04), and doing so with the UBloxM8N library will throw an error. Payload for the latest MON-VER message will be available using Class Method getMonVer.

**Note:** This library does handle the storage of Offline Assist Now messages only the writing of messages to the M8N.

### Constructor: UBloxAssistNow(*ubx*) ###

Initializes Assist Now library. The constructor will enable ACKs for aiding packets, and register message specific callbacks for MON-VER (0x0a04) and MGA-ACK (0x1360) messages. Users must not register callbacks for these, doing so with the UBloxM8N library will throw an error. The latest MON-VER and MGA-ACK payloads are available by calling class method getMonVer and getMgaAck respectively. During initialization the protocol version will be checked, and an error thrown if an unsupported version is detected.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *ubx* | UBloxM8N | Yes | A UBloxM8N intance that has been configured to accept and output UBX messages. |

## Class Methods ##

### getMonVer() ###

Returns the payload from the last MON-VER message

#### Parameters ####

None

#### Return Value ####

A blob.

### writeAssistNow(*assistMsgs[, onDone]*) ###

Takes a blob of binary messages, splits them into individual messages that are then written to the u-blox module one at a time asynchonously. If provided the *onDone* callback will be triggered when all messages have been writtin. The *onDone* callback takes one parameter *errors* which is `null` if no errors were encountered otherwise it contains an array of tables.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *assistMsgs* | blob | Yes | Takes blob of messages from AssistNow Online web request or the persisted AssistNow Offline messages for today's date. |
| *onDone* | function | No | A callback function that is triggered when all assist messages have been written to the M8N. This function has one parameter *errors*, which is null if no errors were encountered when writing messages to the M8N or a array of tables if an error was encountered. (**see below**)|

The *errors* table will always contain *error* and *payload* and may contain more keys:

| Key | Type | Optional | Description |
| --- | --- | --- |--- |
| *error* | String | No | Error message for the type of error encountered |
| *payload* | Blob | No | The raw MGA-ACK message payload |
| *type* | Integer | Yes | Type of acknowledgment. 0 = Message not used by receiver, 1 = Message accepted by receiver |
| *version* | Integer | Yes | Message version (0x00 for M8N) |
| *infoCode* | Integer | Yes | What the receiver chose to do with the message contents. <br>0 =  The receiver accepted the data, <br>1 = The receiver doesn't know the time so can't use the data, <br>2 = The message version is not supported by the receiver, <br>3 = The message size does not match the message version, <br>4 = The message data could not be stored to the database, <br>5 = The receiver is not ready to use the message data, <br>6 = The message type is unknown |
| *msgId* | Integer | Yes | UBX message ID of the ACK'ed message |
| *msgId* | Blob | Yes | The first 4 bytes of the ACK'ed message's payload |

#### Return Value ####

None.

### writeUtcTimeAssist(*currentYear*) ###

Checks if the imp has a valid UTC time by checking that the year returned by the imp API `date()` method is greater than or equal to the *currentYear* parameter. If time is valid, an MGA-INI-TIME-ASSIST-UTC message is written to u-blox module.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *currentYear* | integer | Yes | Current year, ie `2019`. |

#### Return Value ####

Boolean, `true` if imp has a valid date and message was sent, `false` if date was not valid.

### getDateString(*[dateTable]*) ###

Uses the table returned by the imp API `date()` method to create a date string formatted YYYYMMDD. This is the same date formatter used by default in the UBloxAssistNow agent library to organize Offline Assist Now messages by date.

**Note:** This method does not check if the imp has a valid UTC time.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *dateTable* | table | No | Table returned by calling imp API `date()` method. |

#### Return Value ####

String, date fromatted YYYYMMDD.