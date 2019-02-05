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

assistOnlineParams <- {
    "gnss"     : ["gps", "glo"],
    "datatype" : ["eph", "alm", "aux"]
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

function convertToDecimalDegStr(raw) {
    local int = raw / 10000000;
    local dec = raw % 10000000;
    return format("%d.%07d", int, dec);
}

function getLatLonDirStr(lat, lon) {
    local latDir = (lat >= 0) ? 'N' : 'S';
    if (lat < 0) lat =- lat;
    local latDD = convertToDecimalDegStr(lat);

    local lonDir = (lon >= 0) ? 'E' : 'W';
    if (lon < 0) lon =- lon;
    local lonDD = convertToDecimalDegStr(lon);

    return format("%s %c, %s %c", latDD, latDir, lonDD, lonDir);
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
        server.log(format("count %d, awakefor %.1fs, fixtime %.1fs, lastfix %.1fs, satellites %d, time %s, h-accuracy %.1fm, lat/lon %s",
                          nv.reports,
                          report.awakeFor,
                          report.fix.fixTime,
                          report.fix.lastFix,
                          report.fix.numSats,
                          report.fix.time,
                          report.fix.accuracy,
                          getLatLonStr(report.fix.lat, report.fix.lon)));
    }
}

// RUNTIME
// ----------------------------------------------------------------------------------------

server.log("Agent running...");

// Open Device Listeners
device.on("reqAssist", function(dummy) {
  assist.requestOnline(assistOnlineParams, onlineReqHandler);
});
device.on("fix", reportFix);
