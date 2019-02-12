// MIT License
//
// Copyright 2019 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

enum UBLOX_ASSIST_NOW_CONST {
    MGA_INI_TIME_CLASS_ID                = 0x1340,
    MGA_ACK_CLASS_ID                     = 0x1360,
    MON_VER_CLASS_ID                     = 0x0a04,
    CFG_NAVX5_CLASS_ID                   = 0x0623,

    MGA_INI_TIME_UTC_LEN                 = 24,
    MGA_INI_TIME_UTC_TYPE                = 0x10,
    MGA_INI_TIME_UTC_LEAP_SEC_UNKNOWN    = 0x80,
    MGA_INI_TIME_UTC_ACCURACY            = 0x0003,

    CFG_NAVX5_MSG_VER_0                  = 0x0000,
    CFG_NAVX5_MSG_VER_2                  = 0x0002,
    CFG_NAVX5_MSG_VER_3                  = 0x0003,

    CFG_NAVX5_MSG_VER_3_LEN              = 44,
    CFG_NAVX5_MSG_VER_0_2_LEN            = 40,

    CFG_NAVX5_MSG_MASK_1_SET_ASSIST_ACK  = 0x0400,
    CFG_NAVX5_MSG_ENABLE_ASSIST_ACK      = 0x01,

    DEFAULT_WRITE_TIMEOUT                = 2
}

enum UBLOX_ASSIST_NOW_ERROR {
    INITIALIZATION_FAILED          = "Error: Initialization failed. %s",
    PROTOCOL_VERSION_NOT_SUPPORTED = "Error: Protocol version not supported",
    UBLOX_M8N_REQUIRED             = "Error: UBloxM8N required",
    GNSS_ASSIST_CANT_USE           = "Error: GNSS Assistance message can't be used. Receiver doesn't know the time.",
    GNSS_ASSIST_VER_NOT_SUPPORTED  = "Error: GNSS Assistance message version not supported by receiver",
    GNSS_ASSIST_SIZE_MISMATCH      = "Error: GNSS Assistance message size does not match message version",
    GNSS_ASSIST_CANT_BE_STORED     = "Error: GNSS Assistance message data could not be stored",
    GNSS_ASSIST_RECIEVER_NOT_READY = "Error: Receiver not ready to use GNSS Assistance message",
    GNSS_ASSIST_TYPE_UNKNOWN       = "Error: GNSS Assistance message type unknown",
    GNSS_ASSIST_UNDEFINED          = "Error: GNSS Assistance message undefined",
    GNSS_ASSIST_WRITE_TIMEOUT      = "Error: GNSS Assistance write timed out",
    PAYLOAD_PARSING                = "Error: Could not parse payload, %s"
}

/**
 * Class that manages writing Ublox Assist Now messages to the Ublox M8N module and is dependant on
 * the UBloxM8N (Driver) and UbxMsgParser libraries.
 * This class does not manage the stoage of Assist Offline messages, only the writing of assist messages
 * (both Online and Offline) to the M8N.
 * This class registers message callbacks for MGA-ACK (0x1360) and MON-VER (0x0a04). If using this
 * class the code **MUST NOT** register handlers.
 *
 * @class
 */
class UBloxAssistNow {

    static VERSION = "0.1.0";

    // UBloxM8N driver, must be pre-configured to accept ubx messages
    _ubx = null;

    // Assistance messages queue
    _assist = null;
    // Assist queue empty after send callback
    _assistDone = null;
    // Collects all errors encountered when writing assist messages to module
    _assistErrors = null;

    _writeTimer = null;
    _writeTimeout = null;

    // Flag that indicates we have recieved our fist communication from UBloxM8N
    _gpsReady = null;
    // Stores the latest parsed payload from MON-VER message
    _monVer = null;

    /**
     * Initializes Assist Now library. The constructor will enable ACKs for aiding packets, and register message specific
     * callbacks for MON-VER (0x0a04) and MGA-ACK (0x1360) messages. Users must not register callbacks for these. The
     * latest MON-VER and MGA-ACK payloads are available by calling class method getMonVer and getMgaAck respectively.
     * During initialization the protocol version will be checked, and an error thrown if an unsupported version is
     * detected.
     *
     * @param {UBloxM8N} ubx - A UBloxM8N intance that has been configured to accept and output UBX messages.
     */
    constructor(ubx) {
        // add check for required libraries
        local rt = getroottable();
        if (!("UBloxM8N" in rt)) throw UBLOX_ASSIST_NOW_ERROR.UBLOX_M8N_REQUIRED;

        _gpsReady = false;
        _assist = [];
        _assistErrors = [];

        _ubx  = ubx;
        _writeTimeout = UBLOX_ASSIST_NOW_CONST.DEFAULT_WRITE_TIMEOUT;

        // Configures handlers for MGA-ACK and MON-VER messages, checks protocol version, confirms gps is ready/receiving commands
        _init();
    }

    /**
     * Returns the payload from the last MON-VER message
     *
     * @return {blob} - from the last MON-VER message
     */
    function getMonVer() {
        return _monVer;
    }

    /**
     * Controls the max wait to receive an ACK before writing next Assist Now message.
     * If no ACK is received in this time, a message will be added to the error array
     * passed to the writeAssistNow onDone callback. Default is 2s, and works well for
     * UART baud rate of 11520. If another baud rate is used, use this method to adjust
     * the timeout.
     */
    function setAssistNowWriteTimeout(newTimeout) {
        _writeTimeout = newTimeout;
    }

    /**
     * Uses the imp API date method to create a date string. (This matches the agent library date string formatter)
     *
     * @param {[d]} table - table returned by imp API date method.
     * @return {string} - date fromatted YYYYMMDD
     */
    function getDateString(d = null) {
        // Make filename; offline assist data is valid for the UTC day (ie midpoint is midday UTC)
        local d = (d == null) ? date() : d;
        return format("%04d%02d%02d", d.year, d.month + 1, d.day);
    }

    /**
     * @typedef {table} AssistWriteMessage
     * @property {string} error - Error message for the type of write error encountered.
     * @property {blob} payload - The raw MGA-ACK message payload.
     * @property {integer} [type] - Type of acknowledgment (0 not used, 1 accepted by receiver)
     * @property {integer} [version] - Message version (should be 0x00)
     * @property {integer} [infoCode] - Integer that refers to what the receiver chose to do with the message contents
     * @property {integer} [msgId] - UBX message Id of ACK'd message
     * @property {blob} [msgPayloadStart] - First 4 bytes of ACK'd message paylaod
    */

    /**
     * Creates a message queue and begins the loop that writes the current assist message queue to u-blox module.
     *
     * @param {blob} assistMsgs - Takes blob of messages from AssistNow Online web request or the persisted
     *      AssistNow Offline messages for today's date.
     * @param {onAssistWriteDoneCallback} onDone - Callback function that is triggered when all messages
     *      in queue have been written to the Ublox module.
     */
    /**
     * Callback to be executed when all assist messages have been written to Ublox module.
     *
     * @callback onAssistWriteDoneCallback
     * @param {AssistWriteMessage[]|null} errors - Null if no errors were found, otherwise a array of parsed ACK messages with error.
     */
    function writeAssistNow(assistMsgs, onDone = null) {
        // Set callback
        _assistDone = onDone;
        // Write messages if any
        _createAssistQueue(assistMsgs) ? _writeAssist() : _assistDone(null);
    }

    /**
     * Checks if the imp has a valid UTC time using the current year parameter. If time
     * is valid, an MGA_INI_TIME_ASSIST_UTC message is written to u-blox module.
     *
     * @param {integer} currYear - Current year (ie 2019).
     * @return {bool} - if date was valid and assist message was written to u-blox
     */
    function writeUtcTimeAssist(currYear) {
        local d = date();

        if (d.year <= currYear) {
            // Form UBX-MGA-INI-TIME_UTC message
            local timeAssist = blob(UBLOX_ASSIST_NOW_CONST.MGA_INI_TIME_UTC_LEN);

            timeAssist.writen(UBLOX_ASSIST_NOW_CONST.MGA_INI_TIME_UTC_TYPE, 'b');
            // Msg Type & Time reference on reception ok with zero blob default
            timeAssist.seek(3, 'b');
            timeAssist.writen(UBLOX_ASSIST_NOW_CONST.MGA_INI_TIME_UTC_LEAP_SEC_UNKNOWN, 'b');
            timeAssist.writen(d.year & 0xFF, 'b');
            timeAssist.writen(d.year >> 8, 'b');
            timeAssist.writen(d.month + 1, 'b');
            timeAssist.writen(d.day, 'b');
            timeAssist.writen(d.hour, 'b');
            timeAssist.writen(d.min, 'b');
            timeAssist.writen(d.sec, 'b');
            timeAssist.seek(16, 'b');
            timeAssist.writen(UBLOX_ASSIST_NOW_CONST.MGA_INI_TIME_UTC_ACCURACY, 'w');
            // 11-15 and 18-23 are ok with the zero blob default

            _ubx.writeUBX(UBLOX_ASSIST_NOW_CONST.MGA_INI_TIME_CLASS_ID, timeAssist);
            return true;
        }

        return false;
    }

    //  Takes a blob of binary messages, splits them into individual messages that are then stored in the currrent
    //  message queue, ready to be written to the u-blox module when sendCurrent method is called.
    //  @param {blob} assistMsgs - Takes blob of messages from AssistNow Online web request or the persisted
    //        AssistNow Offline messages for today's date.
    // @return {bool} - if there are any current messages to be sent.
    function _createAssistQueue(assistMsgs) {
        if (assistMsgs == null) return false;

        // Split out messages
        assistMsgs.seek(0, 'b');
        while(assistMsgs.tell() < assistMsgs.len()) {
            // Read header & extract length
            local msg = assistMsgs.readstring(6);
            local bodylen = msg[4] | (msg[5] << 8);
            // Read message body & checksum bytes
            local body = assistMsgs.readstring(2 + bodylen);

            // Push message into array
            _assist.push(msg + body);
        }

        return (_assist.len() > 0);
    }

    // register handlers for 0x0a04, and 0x1360, notify user that they should not
    // define a handlers for 1360 or 0x0a04 if using this library - repsonse from
    // 0x0a04 can be retrived using getMonVer function.
    function _init() {
        _ubx.blockAssistNowMsgCallbacks = false;
        // Register handlers
        _ubx.registerOnMessageCallback(UBLOX_ASSIST_NOW_CONST.MON_VER_CLASS_ID, _monVerMsgHandler.bindenv(this));
        _ubx.registerOnMessageCallback(UBLOX_ASSIST_NOW_CONST.MGA_ACK_CLASS_ID, _mgaAckMsgHandler.bindenv(this));
        _ubx.blockAssistNowMsgCallbacks = true;

        // Test GPS up and get protocol version
        _ubx.writeUBX(UBLOX_ASSIST_NOW_CONST.MON_VER_CLASS_ID, "");
    }

    function _mgaAckMsgHandler(payload) {
        _cancelWriteTimer();
        local res = _parseMgaAck(payload);
        local error = res.error;

        if (error != null) {
            // Parsing error encountered, add parsed response to assistErrors
            _assistErrors.push(res);
        } else if (res.type == 0) {
            // Module encountered an error, update error in parsed response and add to assistErrors
            switch(res.infoCode) {
                case 1:
                    res.error <- UBLOX_ASSIST_NOW_ERROR.GNSS_ASSIST_CANT_USE;
                    break;
                case 2:
                    res.error <- UBLOX_ASSIST_NOW_ERROR.GNSS_ASSIST_VER_NOT_SUPPORTED;
                    break;
                case 3:
                    res.error <- UBLOX_ASSIST_NOW_ERROR.GNSS_ASSIST_SIZE_MISMATCH;
                    break;
                case 4:
                    res.error <- UBLOX_ASSIST_NOW_ERROR.GNSS_ASSIST_CANT_BE_STORED;
                    break;
                case 5:
                    res.error <- UBLOX_ASSIST_NOW_ERROR.GNSS_ASSIST_RECIEVER_NOT_READY;
                    break;
                case 6:
                    res.error <- UBLOX_ASSIST_NOW_ERROR.GNSS_ASSIST_TYPE_UNKNOWN;
                    break;
                default:
                    res.error <- UBLOX_ASSIST_NOW_ERROR.GNSS_ASSIST_UNDEFINED;
            }
            _assistErrors.push(res);
        }

        // Continue write
        _writeAssist();
    }

    function _monVerMsgHandler(payload) {
        // Store payload, so user can have access to it.
        _monVer = payload;

        // Do this only on boot
        if (!_gpsReady) {
            // Get protocol version, this throws error if one is not found
            local protoVer = _getProtVer(payload);

            // Confirm protocol version is supported
            local ver = _getCfgNavx5MsgVersion(protoVer);
            if (ver == null) throw UBLOX_ASSIST_NOW_ERROR.PROTOCOL_VERSION_NOT_SUPPORTED;

            _gpsReady = true;

            // Create payload to enable ACKs for aiding packets
            local navPayload = (ver == UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_3) ?
                blob(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_3_LEN) :
                blob(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_0_2_LEN);
            navPayload.writen(ver, 'w');
            // Set mask bits so only ACK bits are modified
            navPayload.writen(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_MASK_1_SET_ASSIST_ACK, 'w');
            // Set enable ACK bit
            navPayload.seek(17, 'b');
            navPayload.writen(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_ENABLE_ASSIST_ACK, 'b');

            // Write UBX payload
            _ubx.writeUBX(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_CLASS_ID, navPayload);
        }
    }

    // Writes a single assist message from the _assist queue to the u-blox module.
    function _writeAssist() {
        if (!_gpsReady) {
            imp.wakeup(0.5, _writeAssist.bindenv(this));
            return;
        }

        if (_assist.len() > 0) {
            // Remove it and send: it's pre-formatted so just dump it to the UART
            local entry = _assist.remove(0);
            _ubx.writeMessage(entry);
            // Set timeout for write
            _cancelWriteTimer();
            _writeTimer = imp.wakeup(_writeTimeout, function() {
                _cancelWriteTimer();
                local err = {
                    "payload" : entry,
                    "error" : UBLOX_ASSIST_NOW_ERROR.GNSS_ASSIST_WRITE_TIMEOUT
                }
                _assistErrors.push(err);
                _writeAssist();
            }.bindenv(this));
            // server.log(format("Sending %02x%02x len %d", entry[2], entry[3], entry.len()));
        } else {
            _cancelWriteTimer();
            // Trigger done callback when all packets have been sent
            if (_assistDone) {
                if (_assistErrors.len() > 0) {
                    _assistDone(_assistErrors);
                    _assistErrors = [];
                } else {
                    _assistDone(null);
                }
            }
        }
    }

    function _getCfgNavx5MsgVersion(protver) {
        switch(protver) {
            case "15.00":
            case "15.01":
            case "16.00":
            case "17.00":
                return UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_0;
            case "18.00":
            case "19.00":
            case "20.00":
            case "20.01":
            case "20.10":
            case "20.20":
            case "20.30":
            case "22.00":
            case "23.00":
            case "23.01":
                return UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_2;
            case "19.10":
            case "19.20":
                return UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_3;
        }
        return null;
    }

    // Parses 0x1360 (MGA_ACK) UBX message payload.
    // param (blob) payload - parses 8 bytes bytes MGA_ACK message payload.
    // returns table - UBX_MGA_ACK
    //   key (integer) type - Type of acknowledgment: 0 = The message was not
    //      used by the receiver (see infoCode field for an indication of why), 1 = The
    //      message was accepted for use by the receiver (the infoCode field will be 0)
    //   key (integer) version - Message version (0x00 for this version)
    //   key (integer) infoCode - Provides greater information on what the
    //      receiver chose to do with the message contents: 0 = The receiver accepted
    //      the data, 1 = The receiver doesn't know the time so can't use the data
    //      (To resolve this a UBX-MGA-INITIME_UTC message should be supplied first),
    //      2 = The message version is not supported by the receiver, 3 = The message
    //      size does not match the message version, 4 = The message data could not be
    //      stored to the database, 5 = The receiver is not ready to use the message
    //      data, 6 = The message type is unknown
    //   key (integer) msgId - UBX message ID of the ack'ed message
    //   key (blob) msgPayloadStart - The first 4 bytes of the ack'ed message's payload
    function _parseMgaAck(payload) {
        // 0x1360: Expected payload size = 8 bytes
        try {
            payload.seek(0, 'b');
            return {
                "type"            : payload.readn('b'),
                "version"         : payload.readn('b'),
                "infoCode"        : payload.readn('b'),
                "msgId"           : payload.readn('b'),
                "msgPayloadStart" : payload.readblob(4),
                "error"           : null,
                "payload"         : payload
            }
        } catch(e) {
            return {
                "error"   : format(UBLOX_ASSIST_NOW_ERROR.PAYLOAD_PARSING, e),
                "payload" : payload
            }
        }
    }

    function _cancelWriteTimer() {
        if (_writeTimer != null) {
            imp.cancelwakeup(_writeTimer);
            _writeTimer = null;
        }
    }

    // Returns protocol version string or throws an error
    function _getProtVer(payload) {
        // 0x0a04: Expected payload size = 40 + 30*n bytes
        try {
            payload.seek(0, 'b');
            local str = payload.readstring(payload.len());
            // Find Protocol Version in payload
            local sIdx = str.find("PROTVER");
            if (sIdx != null) {
                // Info strings are be 30 bytes long, grab just the protocol version info string
                local protVer = (str.len() - sIdx > 30) ? str.slice(sIdx, sIdx + 30) : str.slice(sIdx);
                // Grab just the version number as a string
                local ex = regexp(@"(\d+)[.](\d+)");
                local match = ex.search(protVer);
                if (match != null) {
                    return protVer.slice(match.begin, match.end);
                }
            }
            throw "";
        } catch(e) {
            if (e.len() == 0) {
                throw format(UBLOX_ASSIST_NOW_ERROR.INITIALIZATION_FAILED, "Protocol version not found.");
            } else {
                throw format(UBLOX_ASSIST_NOW_ERROR.INITIALIZATION_FAILED, "Protocol version parsing error: " + e);
            }
        }
    }

}
