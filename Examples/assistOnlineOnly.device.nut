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

#require "UBloxM8N.device.lib.nut:1.0.0"
#require "UbxMsgParser.lib.nut:1.0.0"
#require "UBloxAssistNow.device.lib.nut:0.1.0"
#require "SPIFlashFileSystem.device.lib.nut:2.0.0"
#require "ConnectionManager.lib.nut:3.1.0"

// CONFIGURE VARIABLES AND INITIALIZE CLASSES
// ----------------------------------------------------------------------------------------

const GPS_ACCURACY_TARGET  = 10.0; // when we get a fix this good, we stop trying & turn GPS off
const DEFAULT_GPS_ACCURACY = 9999;
const FIX_TIMEOUT_SEC      = 60;
const CURRENT_YEAR         = 2019;
const SLEEP_FOR_SEC        = 28800; // 8h (8 * 60 * 60)

enum FIX_TYPE {
    NO_FIX,
    DEAD_REC_ONLY,
    FIX_2D,
    FIX_3D,
    GNSS_DEAD_REC,
    TIME_ONLY
}

// Configure Hardware & Library Variables
cm <- ConnectionManager({ "startBehavior"  : CM_START_NO_ACTION,
                          "blinkupBehavior": CM_BLINK_ALWAYS,
                          "retryOnTimeout" : false,
                          "stayConnected"  : false,
                          "connectTimeout" : 180,
                          "ackTimeout"     : 5.0 });

powergate <- hardware.pinYG;
powergate.configure(DIGITAL_OUT, 1);

gpsUART   <- hardware.uartNU;
ubx       <- UBloxM8N(gpsUART);
assist    <- null;

sffs      <- SPIFlashFileSystem(0x000000, 256 * 1024);
sffs.init();

// Set Application Variables
bootTime               <- hardware.millis();
report                 <- {};
gpsFix                 <- null;
hasFix                 <- false;
enableLogging          <- true;


// HELPER FUNCTIONS
// ----------------------------------------------------------------------------------------

function log(msg) {
    if (enableLogging && cm.isConnected()) server.log(msg);
}

function logErr(msg) {
    if (enableLogging && cm.isConnected()) server.error(msg);
}

function formatBlobLog(b) {
    if (b.len() > 0) {
        local s = "";
        foreach(num in b) {
            s += format("0x%02X ", num);
        }
        return s;
    }
    return "";
}

function logObj(msg) {
    foreach(key, value in msg) {
        if (typeof value == "blob") {
            log(key + ": " + formatBlobLog(value));
        } else {
            log(key + ": " + value);
            if (typeof value == "table" || typeof value == "array") {
                foreach (k, val in value) {
                    local t = typeof val;
                    if (t == blob) {
                        log("\t" + k + ": " + formatBlobLog(val))
                    } else {
                        log("\t" + k + ": " + val);
                        if (t == "table") {
                            foreach (slot, v in val) {
                                log("\t\t" + slot + ": " + v);
                            }
                        }
                    }
                }
            }
        }
    }
}

function logUBX(parsed) {
    if (parsed.error != null) {
        logErr(parsed.error);
        log(parsed.payload);
    } else {
        logObj(parsed);
    }
}

function getAccuracy(hacc) {
    // Squirrel only handles 32 bit signed integers
    // hacc is an unsigned 32 bit integer
    // Read as signed integer and if value is negative set to
    // highly inaccurate default
    hacc.seek(0, 'b');
    local gpsAccuracy = hacc.readn('i');
    return (gpsAccuracy < 0) ? DEFAULT_GPS_ACCURACY : gpsAccuracy / 1000.0;
}

function checkFix(payload) {
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
        gpsFix.accuracy <- getAccuracy(payload.hAcc);

        // Check if GPS has good accuracy
        if (gpsFix.accuracy <= GPS_ACCURACY_TARGET) {
            // Turn off power to GPS
            log(format("GPS accuracy %.1fm", gpsFix.accuracy));
            powergate.configure(DIGITAL_OUT, 0);
        }

        report.fix <- gpsFix;

        // Turn off Satellite Information messages
        ubx.enableUbxMsg(UBX_MSG_PARSER_CLASS_MSG_ID.NAV_SAT, 0, null);
    } else {
        log(format("no fix %d, satellites %d, time %s", fixType, payload.numSV, timeStr));
    }
}

function navMsgHandler(payload) {
    // // This will trigger once a second, so don't log message unless debugging
    // log("In NAV_PVT msg handler...");
    // log("--------------------------------------------");
    // log("Msg len: " + payload.len());

    local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.NAV_PVT](payload);
    if (parsed.error == null) {
        checkFix(parsed);
    } else {
        logErr(parsed.error);
        log(paylaod);
    }
    // log("--------------------------------------------");
}

function satMsgHandler(payload) {
    log("In NAV_SAT msg handler...");
    log("--------------------------------------------");
    log("Msg len: " + payload.len());

    local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.NAV_SAT](payload);
    logUBX(parsed);
    log("--------------------------------------------");
}

function ackHandler(payload) {
    log("In ACK_ACK msg handler...");
    log("--------------------------------------------");
    local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.ACK_ACK](payload);
    if (parsed.error != null) {
        logErr(parsed.error);
    } else {
        log(format("ACK-ed msgId: 0x%04X", parsed.ackMsgClassId));
    }
    log("--------------------------------------------");
}

function nakHandler(payload) {
    log("In ACK_NAK msg handler...");
    log("--------------------------------------------");
    local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.ACK_NAK](payload);
    if (parsed.error != null) {
        logErr(parsed.error);
    } else {
        logErr(format("NAK-ed msgId: 0x%04X", parsed.nakMsgClassId));
    }
    log("--------------------------------------------");
}

function ubxMsgHandler(payload, classId) {
    log("In ubx msg handler...");
    log("--------------------------------------------");

    // Log message info
    log(format("Msg Class ID: 0x%04X", classId));
    log("Msg len: " + payload.len());

    // Log UBX message
    if (classId in UbxMsgParser) {
        local parsed = UbxMsgParser[classId](payload);
        logUBX(parsed);
    } else {
        log(payload);
    }

    log("--------------------------------------------");
}

function nmeaMsgHandler(sentence) {
    log("In NMEA msg handler...");
    // Log NMEA message
    log(sentence);
}

function onMessage(msg, classId = null) {
    if (classId != null) {
        // Received UBX message
        ubxMsgHandler(msg, classId);
     } else {
         // Received NMEA sentence
         nmeaMsgHandler(msg);
     }
}

function assistMsgWriteDone(errors) {
    if (errors == null) {
        log("All assist messages written to u-blox.");
    } else {
        log("Errors while writing assist messages: ");
        logObj(errors);
    }
}

function writeAssistMsgs(msgs) {
    if (assist.setCurrent(msgs)) {
        // We have a queue of assist messages, start send
        assist.sendCurrent(assistMsgWriteDone);
    }
}

function enterSleep() {
    // Send whatever fix we have, and total time awake
    report.awakeFor <- (hardware.millis() - bootTime) / 1000.0;
    agent.send("fix", report);
    cm.disconnect(true, 2);
    imp.deepsleepfor(SLEEP_FOR_SEC);
}

function onConnection() {
    // Fix yet? If not ask for online assist
    if (gpsFix == null) {
        log("No fix by connect time: asking agent for assistance");
        agent.send("reqAssist", null);

        // Log u-blox software version
        imp.wakeup(1, function() {
            log("Get u-blox Software Version...");
            local swVersion = assist.getMonVer();
            if (swVersion != null) {
                logUBX(assist.getMonVer());
            } else {
                log("u-blox Software Version not available.");
            }
        })

        // Power down after defined timeout
        imp.wakeup(FIX_TIMEOUT_SEC, function() {
            enterSleep();
        });
    } else {
        // Power down
        imp.onidle(function() {
            enterSleep();
        });
    }
}

// RUNTIME
// ----------------------------------------------------------------------------------------

log("Device running...");
imp.enableblinkup(true);
log("Imp Software Version...");
log(imp.getsoftwareversion());

// Configure u-blox in UBX mode
log("Configuring u-blox...");
ubx.configure({ "baudRate"     : 115200,
                "outputMode"   : UBLOX_M8N_MSG_MODE.UBX_ONLY,
                "inputMode"    : UBLOX_M8N_MSG_MODE.BOTH,
                "defaultOnMsg" : onMessage });

// Register command ACK and NAK callbacks
ubx.registerOnMessageCallback(UBX_MSG_PARSER_CLASS_MSG_ID.ACK_ACK, ackHandler);
ubx.registerOnMessageCallback(UBX_MSG_PARSER_CLASS_MSG_ID.ACK_NAK, nakHandler);

// Now that M8N is configured, initialize AssistNow library
assist <- UBloxAssistNow(ubx, sffs);

log("Enable navigation messages...");
// Satellite Information every 5 sec
ubx.enableUbxMsg(UBX_MSG_PARSER_CLASS_MSG_ID.NAV_SAT, 5, satMsgHandler);
// Position Velocity Time Solution every 1 sec
ubx.enableUbxMsg(UBX_MSG_PARSER_CLASS_MSG_ID.NAV_PVT, 1, navMsgHandler);

// Register agent-device com handlers
agent.on("assistOnline", writeAssistMsgs);

// Try to send a UBX time assistance packet - if using online only
if (assist.sendUtcTimeAssist(CURRENT_YEAR)) {
    log("Time assist msg sent.");
} else {
    log("Don't have a valid time. Time assist msg not sent.");
}

// When we're connected, check for fix. If we don't have it, ask for assistance
cm.onConnect(onConnection);

cm.onTimeout(function() {
    cm.log("Failed to connect, sleeping");
    enterSleep();
});

// Wait for GPS to boot, Start a connection
imp.wakeup(0, function() { cm.connect(); });
