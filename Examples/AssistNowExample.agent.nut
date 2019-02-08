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

#require "UBloxAssistNow.agent.lib.nut:1.0.0"

// CONFIGURE CONSTANTS
// ----------------------------------------------------------------------------------------

const UBLOX_ASSISTNOW_TOKEN = "<YOUR_UBLOX_ASSIST_NOW_TOKEN>";

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

// APPLICATION CLASS
// ----------------------------------------------------------------------------------------


class Application {

    assistOnlineParams  = null;
    assistOfflineParams = null;
    assist              = null;
    persist             = null;

    constructor() {
        assist  = UBloxAssistNow(UBLOX_ASSISTNOW_TOKEN);
        persist = server.load();

        assistOnlineParams = {
            "gnss"     : ["gps", "glo"],
            "datatype" : ["eph", "alm", "aux"]
        };
        assistOfflineParams = {
            "gnss"   : ["gps", "glo"],
            "period" : 1,
            "days"   : 3
        };

        // Open Device Listeners
        device.on(COM_NAMES.REQ_ASSIST, getAssist.bindenv(this));
        device.on(COM_NAMES.FIX, reportFix.bindenv(this));
    }

    // LOCATION HELPERS
    // -----------------------------------------------------------

    function getAssist(type) {
        switch (type) {
            case ASSIST_NOW_TYPE.ONLINE:
                assist.requestOnline(assistOnlineParams, onlineReqHandler.bindenv(this));
                break;
            case ASSIST_NOW_TYPE.OFFLINE:
                assist.requestOffline(assistOfflineParams, offlineReqHandler.bindenv(this));
                break;
            default:
                server.error("unknow assist type: " + type);
        }
    }

    function onlineReqHandler(error, resp) {
        if (error != null) {
            server.error("Online req error: " + error);
            return;
        }

        server.log("Received AssistNow Online. Data length: " + resp.body.len());
        device.send(COM_NAMES.ASSIST_ONLINE, resp.body);
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
        device.send(COM_NAMES.ASSIST_OFFLINE, assistData);
    }

    // FIX HELPERS
    // -----------------------------------------------------------

    function reportFix(report) {
        // Increment number of reports
        if (persist.len() == 0) {
            persist <- {"reports" : 1};
        } else {
            persist.reports++;
        }
        server.save(persist);

        if (!("fix" in report)) {
            server.log("No fix before timeout");
        } else {
            server.log("imp sw version: " + report.impSWVer);
            server.log("u-blox info: " + http.jsonencode(report.ubloxSwVer));
            server.log(format("count %d, awakefor %.1fs, fixtime %.1fs, lastfix %.1fs, satellites %d, time %s, h-accuracy %.1fm, lat/lon %s",
                              persist.reports,
                              report.awakeFor,
                              report.fix.fixTime,
                              report.fix.lastFix,
                              report.fix.numSats,
                              report.fix.time,
                              report.fix.accuracy,
                              getLatLonDirStr(report.fix.lat, report.fix.lon)));
        }
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

    function convertToDecimalDegStr(raw) {
        local int = raw / 10000000;
        local dec = raw % 10000000;
        return format("%d.%07d", int, dec);
    }

}

// RUNTIME
// ----------------------------------------------------------------------------------------

Application();