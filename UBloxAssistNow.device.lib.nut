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
    MGA_ACK_CLASS_ID                     = 0x1360,
    MON_VER_CLASS_ID                     = 0x0a04,
    CFG_NAVX5_CLASS_ID                   = 0x0623,

    CFG_NAVX5_MSG_VER_0                  = 0x0000,
    CFG_NAVX5_MSG_VER_2                  = 0x0002,
    CFG_NAVX5_MSG_VER_3                  = 0x0003,

    CFG_NAVX5_MSG_VER_3_LEN              = 44,
    CFG_NAVX5_MSG_VER_0_2_LEN            = 40,

    CFG_NAVX5_MSG_MASK_1_SET_ASSIST_ACK  = 0x0400,
    CFG_NAVX5_MSG_ENABLE_ASSIST_ACK      = 0x01,

    ERROR_PROTOCOL_VERSION_NOT SUPPORTED = "Error: Protocol version not supported",
    ERROR_OFFLINE_ASSIST                 = "Error: Offline assist requires spi flash file system",
    ERROR_UBLOX_M8N_REQUIRED             = "Error: UBloxM8N and UbxMsgParser required",
}

// This class wraps some of the commands as defined by [Reciever Description Including Protocol Specification document](https://www.u-blox.com/sites/default/files/products/documents/u-blox8-M8_ReceiverDescrProtSpec_%28UBX-13003221%29_Public.pdf)

/**
 * The device-side library for managing Ublox Assist Now messages that help Ublox M8N get a fix faster. This class is dependent on the UBloxM8N and UbxMsgParser libraries.
 * If Assist Offline is used this library also requires Spi Flash File System library.
 *
 * @class
 */
class UBloxAssistNow {

    static VERSION = "1.0.0";

    // UBloxM8N driver, must be pre-configured to accept ubx messages
    _ubx = null;
    // SPI Flash File system - store assist files, already initialized with space alocated
    _sffs = null;

    // Assistance messages queue
    _assist = null;
    // Assist queue empty after send callback
    _assistDone = null;
    // Collects all errors encountered when writing assist messages to module
    _assistErrors = null;

    // Flag that tracks if we have refreshed assist offline this boot
    _assistOfflineRefreshed = null;
    // Flag that indicates we have recieved our fist communication from UBloxM8N
    _gpsReady = null;
    // Stores the latest parsed payload from MON-VER message
    _monVer = null;

    /**
     * Initializes Assist Now library. The constructor will enable ACKs for aiding packets, and register message specific
     * callbacks for MON-VER (0x0a04) and MGA-ACK (0x1360) messages. Users must not register callbacks for these. The latest
     * MON-VER payload is available by calling class method getMonVer. During initialization the protocol version will be
     * checked, and an error thrown if an unsupported version is detected.
     *
     * @param {UBloxM8N} ubx - A UBloxM8N intance that has been configured to accept and output UBX messages.
     * @param {SPIFlashFileSystem} [sffs] - An initialized SPI Flash File system object. This is required if Offline Assist is used.
     */
    constructor(ubx, sffs = null) {
        // add check for required libraries
        local rt = getroottable();
        if (!("UBloxM8N" in rt) || !("UbxMsgParser" in rt)) throw UBLOX_ASSIST_NOW_CONST.ERROR_UBLOX_M8N_REQUIRED;

        _assistOfflineRefreshed = false;
        _gpsReady = false;
        _assist = [];
        _assistErrors = [];

        _ubx  = ubx;
        _sffs = sffs; // Required for offline assist

        // Configures handlers for MGA-ACK and MON-VER messages, checks protocol version, confirms gps is ready/receiving commands
        _init();
    }

    /**
     * Returns the parsed payload from the last MON-VER message
     *
     * @return {table}
     *      @tableEntry {integer} type - Type of acknowledgment: 0 = The message was not
     *          used by the receiver (see infoCode field for an indication of why), 1 = The
     *          message was accepted for use by the receiver (the infoCode field will be 0)
     *      @tableEntry {integer} version - Message version (0x00 for this version)
     *      @tableEntry {integer} infoCode - Provides greater information on what the
     *          receiver chose to do with the message contents: 0 = The receiver accepted
     *          the data, 1 = The receiver doesn't know the time so can't use the data
     *          (To resolve this a UBX-MGA-INITIME_UTC message should be supplied first),
     *          2 = The message version is not supported by the receiver, 3 = The message
     *          size does not match the message version, 4 = The message data could not be
     *          stored to the database, 5 = The receiver is not ready to use the message
     *          data, 6 = The message type is unknown
     *      @tableEntry {integer} msgId - UBX message ID of the ack'ed message
     *      @tableEntry {blob} msgPayloadStart - The first 4 bytes of the ack'ed message's
     *          payload
     */
    function getMonVer() {
        return _monVer;
    }

    /**
     * Updates assist message queue.
     *
     * @param {blob} assistMsgs - Takes message blob from Online Assist agent message or persisted Offline Assist.
     *
     * @return {bool} - if assist queue has any messages
     */
    function updateAssistQueue(assistMsgs) {
        if (assistMsgs == null) return false;

        // Split out messages
        while(assistMsgs.tell() < assistMsgs.len()) {
            // Read header & extract length
            local msg = assistMsgs.readstring(6);
            local bodylen = msg[4] | (msg[5] << 8);
            // Read message body & checksum bytes
            local body = assistMsgs.readstring(2 + bodylen);

            // Push message into array
            assist.push(msg+body);
        }

        return (assist.len() > 0);
    }

    /**
     * Starts to write assist message queue to Ublox module.
     *
     * @param {onAssistWriteDoneCallback} onDone - Callback function that is triggered when all messages in queue have been
     *      written to the Ublox module.
     */
    /**
     * Callback to be executed when all assist messages have been written to Ublox module.
     *
     * @param {error[]/null} errors - Null if no errors were found, otherwise a array of error tables.
     * @callback onAssistWriteDoneCallback
     */
    function startAssistWrite(onDone = null) {
        _assistDone = onDone;
        _writeAssist();
    }

    /**
     * Retrieves Offline Assist messages from storage and returns the messages for today's date.
     * This method will throw an error if the class was not initialized with SPI Flash File System.
     *
     * @param {string} fileName - table of Offline Assist messages from agent organized by date.
     *
     * @return {blob} - stored messages for today
     */
    function getPersistedOfflineAssist(fileName) {
        // We can only use offline assist if we have valid spi flash storage
        if (_sffs == null) throw UBLOX_ASSIST_NOW_CONST.ERROR_OFFLINE_ASSIST;

        // Does assist file exist?
        if (!_sffs.fileExists(fileName)) return null;

        // Open, then read and split into the assist send queue
        local file = _sffs.open(fileName, "r");
        local msgs = file.read();
        file.close();

        return msgs;
    }

    /**
     * Uses the imp API date method to create a date string.
     *
     * @return {string} - date fromatted YYYYMMDD
     */
    function getDayName() {
        // Make filename; offline assist data is valid for the UTC day (ie midpoint is midday UTC)
        local d = date();
        return format("%04d%02d%02d", d.year, d.month + 1, d.day);
    }

    /**
     * Stores Offline Assist messages to SPI organized by file name. When messages are stored toggles flag that
     * indicates messages have been refreshed. This method will throw an error if the class was not initialized
     * with SPI Flash File System.
     *
     * @param {table} mgaAnoMsgsByFileName - table of Offline Assist messages from Offline Assist Web service organized by file name.
     */
    function persistOfflineAssist(mgaAnoMsgsByFileName) {
        // We can only use offline assist if we have valid spi flash storage
        if (_sffs == null) throw UBLOX_ASSIST_NOW_CONST.ERROR_OFFLINE_ASSIST;

        // Store messages by date
        foreach(day, msgs in mgaAnoMsgsByFileName) {
            // If day exists, delete it as new data will be fresher
            if (_sffs.fileExists(day)) {
                _sffs.eraseFile(day);
            }

            // Write day msgs
            local file = _sffs.open(day, "w");
            file.write(msgs);
            file.close();
        }

        // Toggle flag that msgs have been refreshed
        _assistOfflineRefreshed = true;
    }

    /**
     * Returns boolean, if Offline Assist messages have been stored since boot.
     *
     * @return {bool}
     */
    function assistOfflineRefreshed() {
        return _assistOfflineRefreshed;
    }

    // register handlers for 0x0a04, and 0x1360, notify user that they should not
    // define a handlers for 1360 or 0x0a04 if using this library - repsonse from
    // 0x0a04 can be retrived using getMonVer function.
    function _init() {
        // Register handlers
        _ubx.registerMsgHandler(UBLOX_ASSIST_NOW_CONST.MON_VER_CLASS_ID,_monVerMsgHandler.bindenv(this));
        _ubx.registerMsgHandler(UBLOX_ASSIST_NOW_CONST.MGA_ACK_CLASS_ID, _mgaAckMsgHandler.bindenv(this));

        // Test GPS up and get protocol version
        ubx.writeUBX(UBLOX_ASSIST_NOW_CONST.MON_VER_CLASS_ID, "");
    }

    function _mgaAckMsgHandler(payload) {
        local res = UbxMsgParser[UBLOX_ASSIST_NOW_CONST.MGA_ACK_CLASS_ID](payload);

        // TODO: Decide if any of these errors stop the next write, and trigger done callback immediately
        if (res.type == 0 && res.infoCode != 0) {
            // Msg was not used by receiver, add error to _assistErrors
            err = {};
            err.payload <- res;
            switch(res.infoCode) {
                case 1:
                    err.desc <- "Error: GNSS Assistance message can't be used. Receiver doesn't know the time.";
                case 2:
                    err.desc <- "Error: GNSS Assistance message version not supported by receiver";
                case 3:
                    err.desc <- "Error: GNSS Assistance message size does not match message version";
                case 4:
                    err.desc <- "Error: GNSS Assistance message data could not be stored";
                case 5:
                    err.desc <- "Error: Receiver not ready to use GNSS Assistance message";
                case 6:
                    err.desc <- "Error: GNSS Assistance message type unknown";
            }
            _assistErrors.push(err);
        }

        // Continue write
        _writeAssist();
    }

    function _monVerMsgHandler(payload) {
        // Store payload, so user can have access to it.
        _monVer = UbxMsgParser[UBLOX_ASSIST_NOW_CONST.MON_VER_CLASS_ID](payload);

        // Do this only on boot
        if (!_gpsReady) {
            _gpsReady = true;

            if ("protver" in _monVer) {
                // Confirm protocol version is supported
                local ver = _getCfgNavx5MsgVersion(_monVer.protver);
                if (ver == null) throw UBLOX_ASSIST_NOW_CONST.ERROR_INVALID_PROTOCOL_VERSION_NOT SUPPORTED;

                // Create payload to enable ACKs for aiding packets
                local payload = (ver == UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_3) ? blob(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_3_LEN) : blob(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_0_2_LEN);
                payload.writen(ver, 'w');
                // Set mask bits so only ACK bits are modified
                payload.writen(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_MASK_1_SET_ASSIST_ACK, 'w');
                // Set enable ACK bit
                payload.seek(17, 'b');
                payload.writen(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_ENABLE_ASSIST_ACK, 'b');

                // Write UBX payload
                ubx.writeUBX(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_CLASS_ID, payload);
            } else {
                // We cannot create a payload without knowing the protversion
                throw UBLOX_ASSIST_NOW_CONST.ERROR_INVALID_PROTOCOL_VERSION_NOT SUPPORTED;
            }
        }
    }

    function _writeAssist() {
        if (!_gpsReady) {
            imp.wakeup(0.5, _writeAssist);
            return;
        }

        if (_assist.len() > 0) {
            // Remove it and send: it's pre-formatted so just dump it to the UART
            local entry = _assist.remove(0);
            _ubx.writeAssist(entry);
            // server.log(format("Sending %02x%02x len %d", entry[2], entry[3], entry.len()));
        } else {
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
                return CFG_NAVX5_MSG_VER_0;
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
                return CFG_NAVX5_MSG_VER_2;
            case "19.10":
            case "19.20":
                return CFG_NAVX5_MSG_VER_3;
        }
        return null;
    }

}