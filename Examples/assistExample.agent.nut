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

#require "UBloxAssistNow.agent.lib.nut:0.1.0"

// CONFIGURE VARIABLES AND INITIALIZE CLASSES
// ----------------------------------------------------------------------------------------

const UBLOX_ASSISTNOW_TOKEN = "<YOUR_UBLOX_ASSIST_NOW_TOKEN>";

enum ASSIST_NOW_TYPE {
    ONLINE,
    OFFLINE
}

assistOnlineParams <- {
    "gnss"     : ["gps", "glo"],
    "datatype" : ["eph", "alm", "aux"]
}

assistOfflineParams <- {
    "gnss"   : ["gps", "glo"],
    "period" : 1,
    "days"   : 3
}

nv <- server.load();
assist <- UBloxAssistNow(UBLOX_ASSISTNOW_TOKEN);

// HELPER FUNCTIONS
// ----------------------------------------------------------------------------------------

function onlineReqHandler(error, resp) {
    if (error != null) {
        server.error("Online req error: " + error);
        return;
    }

    server.log("Received AssistNow Online. Data length: " + resp.body.len());
    device.send("assistOnline", resp.body);
}

function offlineReqHandler(error, resp) {
    if (error != null) {
        server.error("Offline req error: " + error);
        return;
    }

    server.log("Received AssistNow Offline. Data length: " + resp.body.len());
    local assistData = assist.getOfflineMsgByDate(resp);
    // Log Data Lengths
    foreach(day, data in assistData) {
        server.log(format("offline assist for %s len %d", day, data.len()));
    }

    // Send to device
    device.send("assistOffline", assistData);
}

function getAssist(type) {
    switch (type) {
        case ASSIST_NOW_TYPE.ONLINE:
            assist.requestOnline(assistOnlineParams, onlineReqHandler);
            break;
        case ASSIST_NOW_TYPE.OFFLINE:
            assist.requestOffline(assistOfflineParams, offlineReqHandler);
            break;
        default:
            server.error("unknow assist type: " + type);
    }
}

function reportFix(report) {
    // Increment number of reports
    if (nv.len() == 0) {
        nv <- {"reports" : 1};
    } else {
        nv.reports++;
    }
    server.save(nv);

    if (!("fix" in report)) {
        server.log("No fix before timeout");
    } else {
        local lat = report.fix.lat;
        local lad = (lat >= 0) ? 'N' : 'S';
        if (lat < 0) lat =- lat;
        local la1 = lat / 10000000, la2 = lat % 10000000;

        local lon = report.fix.lon;
        local lod = (lon >= 0) ? 'E' : 'W';
        if (lon < 0) lon =- lon;
        local lo1 = lon / 10000000, lo2 = lon % 10000000;

        server.log(format("count %d, awakefor %.1fs, fixtime %.1fs, lastfix %.1fs, satellites %d, time %s, h-accuracy %.1fm, lat/lon %d.%07d %c, %d.%07d %c",
                          nv.reports,
                          report.awakeFor,
                          report.fix.fixTime,
                          report.fix.lastFix,
                          report.fix.numSats,
                          report.fix.time,
                          report.fix.accuracy,
                          la1,la2,lad,
                          lo1,lo2,lod));
    }
}

// RUNTIME
// ----------------------------------------------------------------------------------------

server.log("Agent running...");

// Open Device Listeners
device.on("reqAssist", getAssist);
device.on("fix", reportFix);
