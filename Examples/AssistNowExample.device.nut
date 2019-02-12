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

// INCLUDE LIBRARIES
// ----------------------------------------------------------------------------------------

#require "UBloxM8N.device.lib.nut:1.0.1"
#require "UbxMsgParser.lib.nut:1.0.1"
#require "SPIFlashFileSystem.device.lib.nut:2.0.0"
#require "ConnectionManager.lib.nut:3.1.0"
#require "UBloxAssistNow.device.lib.nut:0.1.0"

// CONFIGURE HELPER CLASSES
// ----------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------

enum LOG_LEVEL {
    TRACE,
    DEBUG,
    INFO,
    ERROR
}

Logger <- {

    "logLevel" : LOG_LEVEL.TRACE,

    "_areConnected" : function() {
        return server.isconnected();
    },

    "init" : function(level, cm) {
        logLevel = level;
        _areConnected = function() {
            return cm.isConnected();
        }
    }

    "trace" : function(msg) {
        if (logLevel <= LOG_LEVEL.TRACE && _areConnected()) {
            server.log("[TRACE] " + msg.tostring());
        }
    },

    "debug" : function(msg) {
        if (logLevel <= LOG_LEVEL.DEBUG && _areConnected()) {
            server.log("[DEBUG] " + msg.tostring());
        }
    },

    "info"  : function(msg) {
        if (logLevel <= LOG_LEVEL.INFO && _areConnected()) {
            server.log("[INFO] " + msg.tostring());
        }
    },

    "error" : function(msg) {
        if (logLevel <= LOG_LEVEL.ERROR && _areConnected()) {
            server.error("[ERROR] " + msg.tostring());
        }
    },

    "logDivider" : function(level) {
        if (logLevel <= level && _areConnected()) {
            server.log("--------------------------------------------");
        }
    }

    "formatObj" : function(obj) {
        // TODO: JSON encode object
        // Note: JSONEncoder library (v2.0.0) currently doesn't support blobs - throws error
        // Just return object for now
        return obj;
    },

    "formatBinary" : function(bin) {
        if (typeof bin != "blob") {
            local b = blob(bin.len());
            b.writestring(bin.tostring());
            return _formatBlob(b);
        } else {
            return _formatBlob(bin);
        }
    },

    "_formatBlob" : function(b) {
        if (b.len() > 0) {
            local s = "";
            foreach(num in b) {
                s += format("0x%02X ", num);
            }
            return s;
        }
        return "";
    }
}

// ----------------------------------------------------------------------------------------

// Manage all persistant storage
// Dependencies: SPIFlashFileSystem
// Initializes: SPIFlashFileSystem
class Persist {

    // SPI Flash File system - store assist files, already initialized with space alocated
    _sffs = null;

    constructor() {
        _sffs = SPIFlashFileSystem(0x000000, 256 * 1024);
        _sffs.init();
    }

    /**
     * Stores data (ie Offline Assist messages by date) to SPI organized by file name.
     *
     * @param {table} dataByFileName - table of messages from Offline Assist Web service. Table slots should be
     *      file name (i.e. a date string) and values should be string or blob (ie all the MGA-ANO messages that
     *      correspond to that date file name).
     */
    function writeFiles(dataByFileName) {
        // Store messages by date
        foreach(day, msgs in dataByFileName) {
            // If day exists, delete it as new data will be fresher
            if (_sffs.fileExists(day)) {
                _sffs.eraseFile(day);
            }

            // Write day msgs
            local file = _sffs.open(day, "w");
            file.write(msgs);
            file.close();
        }
    }

    /**
     * Retrieves file from SPI Flash storage.
     *
     * @param {string} fileName - name of the file.
     *
     * @return {blob|null} - stored messages for the file specified or null if no file by that name
     */
    function getFile(fileName) {
        // Does assist file exist?
        if (!_sffs.fileExists(fileName)) return null;

        // Open, then read and split into the assist send queue
        local file = _sffs.open(fileName, "r");
        local msgs = file.read();
        file.close();

        return msgs;
    }

    /**
     * Erases all files execpt the file passed in from SPI Flash storage.
     *
     * @param {string} safeFileName - name of the file that should not be erased.
     */
    function eraseAllBut(safeFileName) {
        if (!_sffs.fileExists(safeFileName)) {
            _sffs.eraseAll();
        } else {
            local files = getFileList();
            foreach(file in files) {
                local name = file.name;
                if (!(name == safeFileName)) eraseFile(name);
            }
        }
    }
}

// ----------------------------------------------------------------------------------------

const DEFAULT_GPS_ACCURACY = 9999;

enum FIX_TYPE {
    NO_FIX,
    DEAD_REC_ONLY,
    FIX_2D,
    FIX_3D,
    GNSS_DEAD_REC,
    TIME_ONLY
}

// Manages Location Application Logic
// Dependencies: UBloxM8N, UBloxAssistNow, UbxMsgParser
// Initializes: UBloxM8N, UBloxAssistNow
class Location {

    ubx        = null;
    assist     = null;

    gpsFix     = null;
    accTarget  = null;
    onAccFix   = null;

    bootTime   = null;

    constructor(gpsUART, _bootTime) {
        bootTime = _bootTime;

        Logger.trace("Configuring u-blox...");
        ubx = UBloxM8N(gpsUART);
        ubx.configure({ "baudRate"     : 115200,
                        "outputMode"   : UBLOX_M8N_MSG_MODE.UBX_ONLY,
                        "inputMode"    : UBLOX_M8N_MSG_MODE.BOTH,
                        "defaultOnMsg" : _onMessage.bindenv(this) });

        assist = UBloxAssistNow(ubx);

        // Register command ACK and NAK callbacks
        ubx.registerOnMessageCallback(UBX_MSG_PARSER_CLASS_MSG_ID.ACK_ACK, _onACK.bindenv(this));
        ubx.registerOnMessageCallback(UBX_MSG_PARSER_CLASS_MSG_ID.ACK_NAK, _onNAK.bindenv(this));

        Logger.trace("Enable navigation messages...");
        // Satellite Information every 5 sec
        ubx.enableUbxMsg(UBX_MSG_PARSER_CLASS_MSG_ID.NAV_SAT, 5, _onSatMsg.bindenv(this));
        // Position Velocity Time Solution every 1 sec
        ubx.enableUbxMsg(UBX_MSG_PARSER_CLASS_MSG_ID.NAV_PVT, 1, _onNavMsg.bindenv(this));
    }

    function getLocation(accuracy, onAccurateFix) {
        accTarget = accuracy;
        onAccFix = onAccurateFix;

        if (gpsFix != null) {
            _checkAccuracy();
        }
    }

    function writeAssistMsgs(msgs, onDone) {
        assist.writeAssistNow(msgs, onDone);
    }

    function getFixInfo() {
        return gpsFix;
    }

    function getTodayAssistFileName() {
        return assist.getDateString();
    }

    function getUbloxSwVer() {
        local payload = assist.getMonVer();
        local monVer = UbxMsgParser[UBLOX_ASSIST_NOW_CONST.MON_VER_CLASS_ID](payload);
        return monVer;
    }

    // HELPER METHODS
    // -----------------------------------------------------------

    function logUBX(parsed) {
        if (parsed.error != null) {
            Logger.error(parsed.error);
            Logger.debug(Logger.formatBinary(parsed.payload));
        } else {
            Logger.debug(Logger.formatObj(parsed));
        }
    }

    // LOCATION HELPERS
    // -----------------------------------------------------------

    function _checkFix(payload) {
        // Check fixtype
        local fixType = payload.fixType;
        local timeStr = format("%02d:%02d:%02d", payload.year, payload.month, payload.day);

        if (fixType >= FIX_TYPE.FIX_3D) {
            // Get timestamp for this fix
            local fixTime = (hardware.millis() - bootTime) / 1000.0;

            // If this is the first fix, create fix report table
            if (gpsFix == null) {
                // And record time to first fix
                gpsFix = {
                    "fixTime" : fixTime
                };
            }

            // Add/Update fix report values
            gpsFix.lastFix <- fixTime;
            gpsFix.fixType <- fixType;
            gpsFix.numSats <- payload.numSV;
            gpsFix.lon <- payload.lon;
            gpsFix.lat <- payload.lat;
            gpsFix.time <- timeStr;
            gpsFix.accuracy <- _getAccuracy(payload.hAcc);

            if (onAccFix != null) _checkAccuracy();

            // Turn off Satellite Information messages
            ubx.enableUbxMsg(UBX_MSG_PARSER_CLASS_MSG_ID.NAV_SAT, 0, null);
        } else {
            Logger.debug(format("no fix %d, satellites %d, time %s", fixType, payload.numSV, timeStr));
        }
    }

    function _checkAccuracy() {
        // Check if GPS has good accuracy
        if (gpsFix.accuracy <= accTarget) {
            onAccFix(gpsFix);
        }
    }

    function _getAccuracy(hacc) {
        // Squirrel only handles 32 bit signed integers
        // hacc is an unsigned 32 bit integer
        // Read as signed integer and if value is negative set to
        // highly inaccurate default
        hacc.seek(0, 'b');
        local gpsAccuracy = hacc.readn('i');
        return (gpsAccuracy < 0) ? DEFAULT_GPS_ACCURACY : gpsAccuracy / 1000.0;
    }

    // MESSAGE HANDLERS
    // -----------------------------------------------------------

    function _onNavMsg(payload) {
        // This will trigger once a second, so don't log message unless you mean to!!!
        Logger.trace("In NAV_PVT msg handler...");
        Logger.logDivider(LOG_LEVEL.TRACE);
        Logger.trace("Msg len: " + payload.len());

        local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.NAV_PVT](payload);
        if (parsed.error == null) {
            _checkFix(parsed);
        } else {
            Logger.error(parsed.error);
            Logger.debug(paylaod);
        }

        Logger.logDivider(LOG_LEVEL.TRACE);
    }

    function _onSatMsg(payload) {
        // Check this message mainly when in debug mode
        // This will trigger once every 5 seconds
        Logger.debug("In NAV_SAT msg handler...");
        Logger.logDivider(LOG_LEVEL.DEBUG);
        Logger.debug("Msg len: " + payload.len());

        local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.NAV_SAT](payload);
        logUBX(parsed);
        Logger.logDivider(LOG_LEVEL.DEBUG);
    }

    function _onACK(payload) {
        Logger.trace("In ACK_ACK msg handler...");
        Logger.logDivider(LOG_LEVEL.TRACE);

        local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.ACK_ACK](payload);
        if (parsed.error != null) {
            Logger.error(parsed.error);
        } else {
            Logger.trace(format("ACK-ed msgId: 0x%04X", parsed.ackMsgClassId));
        }

        Logger.logDivider(LOG_LEVEL.TRACE);
    }

    function _onNAK(payload) {
        Logger.trace("In ACK_NAK msg handler...");
        Logger.logDivider(LOG_LEVEL.TRACE);

        local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.ACK_NAK](payload);
        if (parsed.error != null) {
            Logger.error(parsed.error);
        } else {
            Logger.error(format("NAK-ed msgId: 0x%04X", parsed.nakMsgClassId));
        }

        Logger.logDivider(LOG_LEVEL.TRACE);
    }

    function _onMessage(msg, classId = null) {
        if (classId != null) {
            // Received UBX message
            _onUbxMsg(msg, classId);
         } else {
             // Received NMEA sentence
             _onNmeaMsg(msg);
         }
    }

    function _onUbxMsg(payload, classId) {
        Logger.trace("In ubx msg handler...");
        Logger.logDivider(LOG_LEVEL.TRACE);

        // Log message info
        Logger.debug(format("Msg Class ID: 0x%04X", classId));
        Logger.debug("Msg len: " + payload.len());

        // Log UBX message
        if (classId in UbxMsgParser) {
            local parsed = UbxMsgParser[classId](payload);
            logUBX(parsed);
        } else {
            Logger.debug(Logger.formatBinary(payload));
        }

        Logger.logDivider(LOG_LEVEL.TRACE);
    }

    function _onNmeaMsg(sentence) {
        Logger.trace("In NMEA msg handler...");
        // Log NMEA message
        Logger.debug(sentence);
    }

}

// ----------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------


// APPLICATION CLASS
// ----------------------------------------------------------------------------------------

const GPS_ACCURACY_TARGET  = 10.0; // when we get a fix this good, we stop trying & turn GPS off
const FIX_TIMEOUT_MS       = 60000;
const CURRENT_YEAR         = 2019;
const SLEEP_FOR_SEC        = 28800; // 8h (8 * 60 * 60)

enum COM_NAMES {
    REQ_ASSIST     = "reqAssist",
    FIX            = "fix",
    ASSIST_ONLINE  = "assistOnline",
    ASSIST_OFFLINE = "assistOffline"
}

enum ASSIST_NOW_TYPE {
    ONLINE,
    OFFLINE
}

// Register handlers, initialize classes
class Application {

    cm        = null;
    location  = null;
    persist   = null;

    powerGate = null;
    gpsUART   = null;

    bootTime  = null;
    report    = null;

    offlineAssistRefreshed = null;

    constructor() {
        bootTime = hardware.millis();
        report = {};
        offlineAssistRefreshed = false;

        configureHardware();
        initializeClasses();
        registerListeners();

        writeAssist();
        location.getLocation(GPS_ACCURACY_TARGET, onAccurateFix.bindenv(this));

        cm.onConnect(onConnection.bindenv(this));
        cm.onTimeout(onConnTimeout.bindenv(this));

        // Start a connection; wait for GPS to boot first
        imp.wakeup(0, function() { cm.connect(); }.bindenv(this));
    }

    // CONNECTION LISTENERS
    // -----------------------------------------------------------

    function onConnection() {
        // Refresh Offline assist
        agent.send(COM_NAMES.REQ_ASSIST, ASSIST_NOW_TYPE.OFFLINE);

        // Fix yet? If not ask for online assist
        if (location.getFixInfo() == null) {
            Logger.debug("No fix by connect time: asking agent for assistance");
            agent.send(COM_NAMES.REQ_ASSIST, ASSIST_NOW_TYPE.ONLINE);
        } else if (offlineAssistRefreshed && "fix" in report) {
            // We have an accurate fix and updated offline assist, send report and sleep
            reportAndSleep();
            return;
        }

        // Set timer, so we are not awake for more than the set timeout
        local awakeFor = hardware.millis() - bootTime;
        local timeout = FIX_TIMEOUT_MS - awakeFor;

        if (timeout <= 0) {
            reportAndSleep();
        } else {
            imp.wakeup(timeout, reportAndSleep.bindenv(this));
        }
    }

    function onConnTimeout() {
        // Store this log, so we will see it on next connect
        cm.log("Failed to connect, sleeping");

        // Enhancement: Store data since we failed to connect

        enterSleep();
    }

    // WAKE/SLEEP HELPERS
    // -----------------------------------------------------------

    function reportAndSleep() {
        // Send whatever fix we have, and total time awake
        if (cm.isConnected()) {
            report.awakeFor <- (hardware.millis() - bootTime) / 1000.0;
            report.impSWVer <- imp.getsoftwareversion();
            report.ubloxSwVer <- location.getUbloxSwVer();
            if (!("fix" in report)) {
                local fix = getFixInfo();
                if (fix != null) report.fix <- fix;
            }
            agent.send(COM_NAMES.FIX, report);
        }

        enterSleep();
    }

    function enterSleep() {
        cm.disconnect(true, 2);

        imp.onidle(function() {
            imp.deepsleepfor(SLEEP_FOR_SEC);
        }.bindenv(this));
    }

    // APPLICATION LOGIC
    // -----------------------------------------------------------

    function writeAssist() {
        // Get today's offline assist messages
        local msgs = persist.getFile(location.getTodayAssistFileName());
        location.writeAssistMsgs(msgs, onAssistWriteDone.bindenv(this));
    }

    function onAccurateFix(fixReport) {
        Logger.debug(format("GPS accuracy %.1fm", fixReport.accuracy));
        // Turn off power to GPS to conserve power
        powerGate.configure(DIGITAL_OUT, 0);
        report.fix <- fixReport;

        // Check if we have completed all tasks and can go to sleep
        if (offlineAssistRefreshed) {
            reportAndSleep();
        }
    }

    function onAssistWriteDone(errors) {
        if (errors != null) {
            Logger.debug("Errors while writing assist messages: ");
            Logger.error(Logger.formatObj(errors));
        } else {
            Logger.debug("All assist messages written to u-blox.");
        }
    }

    function storeOfflineAssist(msgs) {
        persist.eraseAllBut(location.getTodayAssistFileName());
        persist.writeFiles(msgs);
        offlineAssistRefreshed = true;

        // Check if we have completed all tasks and can go to sleep
        if ("fix" in report) {
            reportAndSleep();
        }
    }

    // SETUP HELPERS
    // -----------------------------------------------------------

    function registerListeners() {
        // Register agent-device com handlers
        agent.on(COM_NAMES.ASSIST_ONLINE, function(msgs) {
            location.writeAssistMsgs(msgs, onAssistWriteDone);
        }.bindenv(this));
        agent.on(COM_NAMES.ASSIST_OFFLINE, storeOfflineAssist.bindenv(this));
    }

    function configureHardware() {
        powerGate = hardware.pinYG;
        powerGate.configure(DIGITAL_OUT, 1);

        gpsUART = hardware.uartNU;
    }

    function initializeClasses() {
        local cmSettings = {
            "startBehavior"  : CM_START_NO_ACTION,
            "blinkupBehavior": CM_BLINK_ALWAYS,
            "retryOnTimeout" : false,
            "stayConnected"  : false,
            "connectTimeout" : 180,
            "ackTimeout"     : 5.0
        };

        cm = ConnectionManager(cmSettings);
        Logger.init(LOG_LEVEL.DEBUG, cm);
        persist = Persist();
        location = Location(gpsUART, bootTime);
    }

}

// RUNTIME
// ----------------------------------------------------------------------------------------

Application();