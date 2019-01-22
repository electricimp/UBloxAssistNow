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
    ONLINE_URL            = "https://online-%s.services.u-blox.com/GetOnlineData.ashx",
    OFFLINE_URL           = "https://offline-%s.services.u-blox.com/GetOfflineData.ashx",
    PRIMARY_SERVER        = "live1",
    BACKUP_SERVER         = "live2",
    UBX_MGA_ANO_CLASS_ID  = 0x1320
}

// https://www.u-blox.com/sites/default/files/products/documents/MultiGNSS-Assistance_UserGuide_%28UBX-13004360%29.pdf
// MGA access tokens - http://www.u-blox.com/services-form.html
class UBloxAssistNow {

    // NOTE: Due to u-blox Assist Now usage limits this library may not work at scale. Many
    // imp http requests will come from a single server, and so the u-blox Assist Now services
    // may limit these requests.
    static VERSION = "0.1.0";

    _token   = null;
    _headers = null;

    /**
     * Initializes Assist Now library. The constructor configures the auth that is used for all requests.
     *
     * @param {string} token - The authorization token supplied by u-blox when a client registers to use the service.
     */
    constructor(token) {
        _token   = token;
        _headers = {};
    }

    /**
     * By default there are no HTTP requests headers set, the imp API's defaults will be used. Use this
     * method to customize HTTP request headers.
     *
     * @param {table} headers - Table of HTTP headers.
     */
    function setHeaders(headers) {
        _headers = headers;
    }

    /**
     * Sends HTTP request to get data from the AssistNow Online Service.
     *
     * @param {table} reqParams - Table of request parameters. Can be an empty table.
     * @param {requestCallback} cb - Function that will be triggered when the response from u-blox
     * AssistNow servers is received.
     */
    /**
     * Callback to be executed when the response from u-blox AssistNow servers is received.
     *
     * @callback requestCallback
     * @param {table} error - A string describing the error.
     * @param {http::response} response - HTTP response object return from u-blox AssistNow servers.
     */
    function online(reqParams, cb) {
        local url = format("%s?token=%s;%s",
                      UBLOX_ASSIST_NOW_CONST.ONLINE_URL, _token, _formatOptions(reqParams));
        _sendRequest(url, UBLOX_ASSIST_NOW_CONST.PRIMARY_SERVER, cb);
    }

    /**
     * Sends HTTP request to get data from the AssistNow Offline Service.
     *
     * @param {table} reqParams - Table of request parameters.
     * @param {requestCallback} cb - Function that will be triggered when the response from u-blox
     * AssistNow servers is received.
     */
    /**
     * Callback to be executed when the response from u-blox AssistNow servers is received.
     *
     * @param {table} error - A string describing the error.
     * @param {httpresponse} response - HTTP response object return from u-blox AssistNow servers.
     * @callback requestCallback
     */
    function offline(reqParams, cb) {
        local url = format("%s?token=%s;%s",
                      UBLOX_ASSIST_NOW_CONST.OFFLINE_URL, _token, _formatOptions(reqParams));
        _sendRequest(url, UBLOX_ASSIST_NOW_CONST.PRIMARY_SERVER, cb);
    }

    /**
     * Splits offline response into UBX-MGA-ANO messages organized by date using the specified
     * formatting function.
     *
     * @param {httpresponse} offlineRes - HTTP response object received from AssistNow Offline Service.
     * @param {requestCallback} dateFormatter - Function that takes year, month and day bits and returns
     * a string used as the table slot for all messages containing the same date.
     * @param {bool} logUnknownMsgType - Whether to log message class-id if data contains messages
     * other than UBX-MGA-ANO.
     */
    function getOfflineMsgByDate(offlineRes, dateFormatter = null, logUnknownMsgType = false) {
        if (offlineRes.statuscode != 200) return {};

        // Get result as a blob as we iterate through it
        local v = blob();
        v.writestring(offlineRes.body);
        v.seek(0);

        // Make blank offline assist table to send to device
        // Table consists of date entries with binary strings of concatenated messages for that day
        local assist = {};

        // Build day buckets with all UBX-MGA-ANO messages for a single day in each
        while(v.tell() < v.len()) {
            // Read header & extract length
            local msg = v.readstring(6);
            local bodylen = msg[4] | (msg[5] << 8);
            local classid = msg[2] << 8 | msg[3];

            // Read message body & checksum bytes
            local body = v.readstring(2 + bodylen);

            // Check it's UBX-MGA-ANO
            if (classid == UBLOX_ASSIST_NOW_CONST_UBX_MGA_ANO_CLASS_ID) {
                // Make date string
                // This will be for file name is SFFS is used on device
                if (dateFormatter == null) dateFormatter = formatDateString;
                local d = dateFormatter(body[4], body[5], body[6]);

                // New date? If so create day bucket
                if (!(d in assist)) assist[d] <- "";

                // Append to bucket
                assist[d] += (msg + body);
            } else if (logUnknownMsgType) {
                server.log(format("Unknown classid %04x in offline assist data", classid));
            }
        }

        return assist;
    }

    /**
     * Takes the year, month and day from from AssistNow Offline Service payload and formats into a
     * date string.
     *
     * @return {string} - date fromatted YYYYMMDD
     */
    function formatDateString(year, month, day) {
        return format("%04d%02d%02d", 2000 + year, month, day);
    }

    // Helper that sends HTTP get requests.
    function _sendRequest(url, svr, cb) {
        local req = http.get(format(url, svr), _headers);
        req.sendasync(_respFactory(svr));
    }

    // Helper that returns response handler for HTTP requests.
    function _respFactory(url, svr, cb) {
        // Return a process response function
        return function(resp) {
            local status = resp.statuscode;
            local err = null;

            if (status == 403) {
                // Docs state that status code of 403 will be returned when
                // too many requests are made from the same server, so handling
                // 403 instead of 429.
                err = "ERROR: Overload limit reached.";
            } else if (status < 200 || status >= 300) {
                if (svr == UBLOX_ASSIST_NOW_CONST.PRIMARY_SERVER) {
                    // Retry request using backup server instead
                    // TODO: May want to lengthen request timeout
                    _sendRequest(url, UBLOX_ASSIST_NOW_CONST.BACKUP_SERVER, cb);
                    return;
                }
                // Body should contain an error message string
                err = resp.body;
            }

            cb(err, resp);
        }.bindenv(this);
    }

    // Helper that formats request parameters. Note the required format is not quite URL encode.
    function _formatOptions(opts) {
        local encoded = "";
        foreach(k, v in opts) {
            encoded += (k + "=");
            switch (typeof v) {
                case "string":
                case "integer":
                case "float":
                    ev += (v + ";");
                    break;
                case "array":
                    local last = v.len() - 1;
                    foreach(idx, item in v) {
                        encoded += (idx == last) ? (item + ";") : (item + ",");
                    }
                default:
                    // Data could not be formatted
                    return null;
            }
        }
        return encoded;
    }
}