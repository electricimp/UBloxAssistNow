# UBloxAssistNow 0.1.0 (Device) #

This device library manages the delivery of AssistNow messages to the u-blox M8N module. AssistNow messages help the M8N get a GPS fix faster.

This library depends upon the [UBloxM8N library](https://github.com/electricimp/UBloxM8N). If the UBloxAssistNow library is included, callbacks must not be registered for MGA-ACK (0x1360) and MON-VER (0x0a04) messages using the [UBloxM8N library](https://github.com/electricimp/UBloxM8N). Doing so will throw an exception. The latest MON-VER payload is available by calling the class method [*getMonVer()*](#getmonver). MGA-ACK (0x1360) messages will be processed by the library. If errors found in the MGA-ACK messages, they will be passed to the [*writeAssistNow()*](#writeassistnowassistmsgs-ondonecallback) method's *onDoneCallback*.

**Note** This library does not handle the storage of offline AssistNow messages, only the transmission of messages to the M8N.

**To include this library in your project, add** `#require "UBloxAssistNow.device.lib.nut:0.1.0"` **at the top of your device code.**

## Class Usage ##

### Constructor: UBloxAssistNow(*ubx*) ###

Instantiates and initializes the AssistNow library. It will enable ACKs for aiding packets, and register message-specific callbacks for MON-VER (0x0a04) and MGA-ACK (0x1360) messages. Users must not register callbacks for these messages using the [UBloxM8N library](https://github.com/electricimp/UBloxM8N) or an exception will be thrown.

During initialization the protocol version will be checked, and an exception thrown if an unsupported version is detected.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *ubx* | UBloxM8N | Yes | A UBloxM8N instance that has been configured to accept and output UBX messages |

## Class Methods ##

### getMonVer() ###

This method provides the payload from the last MON-VER message.

#### Returns ####

Blob &mdash; the message payload.

### writeUtcTimeAssist(*currentYear*) ###

This method determines if the imp has a valid UTC time by checking that the year returned by the imp API **date()** method is greater than or equal to the argument passed into the *currentYear* parameter. If time is valid, an MGA-INI-TIME-ASSIST-UTC message is written to u-blox module.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *currentYear* | Integer | Yes | The current year, ie. 2019 |

#### Returns ####

Boolean &mdash; `true` if imp has a valid date, `false` if the date was not valid.

### writeAssistNow(*assistMsgs[, onDoneCallback]*) ###

This method splits a blob of binary messages into individual messages and writes them to the u-blox module one at a time asynchronously. If provided, the onDone callback will be triggered when all the messages have been sent.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *assistMsgs* | Blob | Yes | Messages from AssistNow web service, or persisted AssistNow Offline messages for today’s date |
| *onDoneCallback* | Function | No | A function that is triggered when all of the messages have been sent to the M8N. It has one parameter, *errors*, which will be `null` if no errors were encountered during writing, or [an array of tables](#errors-table) if an error was encountered |

#### Errors Table ####

The *errors* table will always contain *error* and *payload* keys.

| Key | Type | Always&mdash;Included? | Description |
| --- | --- | --- |--- |
| *error* | String | Yes | Error message for the type of error encountered |
| *payload* | Blob | Yes | The raw MGA-ACK message payload |
| *type* | Integer | No | Type of acknowledgment:<br />0 = Message not used by receiver<br />1 = Message accepted by receiver |
| *version* | Integer | No | Message version (0x00 for M8N) |
| *infoCode* | Integer | No | What the receiver did with the message contents:<br />0 =  The receiver accepted the data<br />1 = The receiver doesn’t know the time so can’t use the data<br />2 = The message version is not supported<br />3 = The message size does not match the message version<br />4 = The message data could not be stored in the database<br />5 = The receiver is not ready to use the message data<br />6 = The message type is unknown |
| *msgId* | Integer | No | UBX message ID of the ACK’d message |
| *msgId* | Blob | No | The first four bytes of the ACK’d message’s payload |

#### Returns ####

Nothing.

### setAssistNowWriteTimeout(*timeout*) ###

Controls the maximum time to wait for an ACK before writing next Assist Now message. If no ACK is received in this time, an error will be added to the writeAssistNow onDone callback parameter. The default timeout is 2s, and works well when the UART baud rate is set to 11520. If another baud rate is used, use this method to adjust the timeout.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *timeout* | integer/float | Yes | Maximum time to wait for an Assist Now ACK. |

#### Returns ####

Nothing.

### getDateString(*[dateTable]*) ###

This method takes the output of the Squirrel **date()** function and generates a date string formatted `YYYYMMDD`. This is the same date formatter used by default in the UBloxAssistNow agent library to organize Offline AssistNow messages by date.

**Note** This method does not check if the imp has a valid UTC time.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *dateTable* | Table | No | Table returned by the Squirrel **date()** method |

#### Returns ####

String &mdash; a date formatted as `YYYYMMDD`.

## License ##

These library is licensed under the [MIT License](../LICENSE).