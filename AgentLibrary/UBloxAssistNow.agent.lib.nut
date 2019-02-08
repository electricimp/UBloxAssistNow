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
    ONLINE_URL              = "https://online-%s.services.u-blox.com/GetOnlineData.ashx",
    OFFLINE_URL             = "https://offline-%s.services.u-blox.com/GetOfflineData.ashx",
    PRIMARY_SERVER          = "live1",
    BACKUP_SERVER           = "live2",
    UBX_MGA_ANO_CLASS_ID    = 0x1320,
    UBX_HEADER_BYTE_1       = 0xB5,
    UBX_HEADER_BYTE_2       = 0x62,
    ERROR_INVALID_REQ_OPTS  = "Error: Request options could not be encoded. AssistNow request not sent.",
    ERROR_REQ_OVERLOAD      = "Error: Overload limit reached.",
    ERROR_REQ_INVALID_PARAM = "Error: Request failed. Invalid request parameter: %s.",
    ERROR_REQ_INVALID_TOKEN = "Error: Request failed. Invalid token.",
}

/**
 * Agent library used to retrieve data from u-blox AssistNow servers. Data supplied
 * by the AssistNow Services is used by a u-blox GNSS receiver in order to substantially
 * reduce Time To First Fix, even under poor signal conditions. For information about
 * AssistNow services see this [user guide](https://www.u-blox.com/sites/default/files/products/documents/MultiGNSS-Assistance_UserGuide_%28UBX-13004360%29.pdf)
 * MGA access tokens - http://www.u-blox.com/services-form.html
 */
class UBloxAssistNow {

    // NOTE: Due to u-blox Assist Now usage limits this library may not work at scale. Many
    // imp http requests will come from a single server, and so the u-blox Assist Now services
    // may limit these requests.
    static VERSION = "1.0.0";

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
    function requestOnline(reqParams, cb) {
        local options = _formatOptions(reqParams);

        if (options == null) {
            cb(UBLOX_ASSIST_NOW_CONST.ERROR_INVALID_REQ_OPTS, null);
        } else {
            local url = format("%s?token=%s;%s", UBLOX_ASSIST_NOW_CONST.ONLINE_URL, _token, options);
            _sendRequest(url, UBLOX_ASSIST_NOW_CONST.PRIMARY_SERVER, cb);
        }
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
    function requestOffline(reqParams, cb) {
        local options = _formatOptions(reqParams);

        if (options == null) {
            cb(UBLOX_ASSIST_NOW_CONST.ERROR_INVALID_REQ_OPTS, null);
        } else {
            local url = format("%s?token=%s;%s", UBLOX_ASSIST_NOW_CONST.OFFLINE_URL, _token, options);
            _sendRequest(url, UBLOX_ASSIST_NOW_CONST.PRIMARY_SERVER, cb);
        }
    }

    /**
     * Splits offline response into UBX-MGA-ANO messages organized by date using the specified
     * formatting function.
     *
     * @param {httpresponse} offlineRes - HTTP response object received from AssistNow Offline Service.
     * @param {requestCallback} dateFormatter - Function that takes year, month and day bits and returns
     * a string used as the table slot for all messages containing the same date.
     * @param {bool} logErrors - Whether to log errors, response status code not 200, msg class-id
     * not UBX-MGA-ANO, or dropped bytes if corrupted packet encountered.
     */
    function getOfflineMsgByDate(offlineRes, dateFormatter = null, logErrors = false) {
        if (offlineRes.statuscode != 200) {
            if (logErrors) server.error("Offline response statuscode: " + offlineRes.statuscode);
            return {};
        }

        // Write offline response data to a blob, so we can parse messages
        local b = blob(offlineRes.body.len());
        b.writestring(offlineRes.body);
        b.seek(0, 'b');

        // Make offline assist table of date entries with binary strings of concatenated messages for that day to send to device
        local assist = {};
        local p = 0;
        local l = b.len();
        local parsingError = null;

        // Build day buckets with all UBX-MGA-ANO messages for a single day in each
        while((p = b.tell()) < l) {
            // Note: These checks will not eliminate a corrupted packet from being passed on/stored, but will get the next packets back on track after corrupted packet is encountered. The module can deal with corrupted data, so we are not validating packet length, check sum etc.

            // Confirm ubx header
            if (b[p] == UBLOX_ASSIST_NOW_CONST.UBX_HEADER_BYTE_1 &&
                b[p + 1] == UBLOX_ASSIST_NOW_CONST.UBX_HEADER_BYTE_2) {

                if (logErrors && parsingError != null) {
                    server.error("Error parsing offline assist data. Dropped data: ");
                    server.error(parsingError);
                    parsingError = null;
                }

                // Read header & extract length
                local msg = b.readstring(6);
                local classid = msg[2] << 8 | msg[3];
                local bodylen = msg[4] | (msg[5] << 8);
                // Read message body & checksum bytes
                local body = b.readstring(2 + bodylen);

                // Add to assist table if it's a UBX-MGA-ANO msg
                if (classid == UBLOX_ASSIST_NOW_CONST.UBX_MGA_ANO_CLASS_ID) {
                    // Make date string, this will be the file name used to store msgs in SFFS on the device
                    if (dateFormatter == null) dateFormatter = formatDateString;
                    local d = dateFormatter(body[4], body[5], body[6]);

                    // New date? If so create day bucket
                    if (!(d in assist)) assist[d] <- "";

                    // Append to bucket
                    assist[d] += (msg + body);
                } else {
                    if (logErrors) server.error(format("Unknown classid %04x in offline assist data", classid));
                }
            } else {
                // Move pointer ahead to next byte by adding byte to parsing error string
                if (parsingError == null) parsingError = "";
                parsingError += b.readstring(1);
            }
        }

        if (logErrors && parsingError != null) {
            server.error("Error parsing offline assist data. Dropped data: ");
            server.error(parsingError);
            parsingError = null;
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
        req.sendasync(_respFactory(url, svr, cb));
    }

    // Helper that returns response handler for HTTP requests.
    function _respFactory(url, svr, cb) {
        // Return a process response function
        return function(resp) {
            local status = resp.statuscode;
            local err = null;

            if (status == 200) {

            } else if (status == 403) {
                // Docs state that status code of 403 will be returned when
                // too many requests are made from the same server, so handling
                // 403 instead of 429.
                err = UBLOX_ASSIST_NOW_CONST.ERROR_REQ_OVERLOAD;
            } else {
                if (status == 400) {
                    // Look for known errors that retry would not help with
                    foreach(k, v in resp.headers) {
                        if (k.find("400 invalid parameter") != null) {
                            err = format(UBLOX_ASSIST_NOW_CONST.ERROR_REQ_INVALID_PARAM, v);
                        } else if (k.find("400 invalid token") != null) {
                            err = UBLOX_ASSIST_NOW_CONST.ERROR_REQ_INVALID_TOKEN;
                        }
                    }
                }

                // If we didn't fine a known error, retry with backup server
                if (err == null && svr == UBLOX_ASSIST_NOW_CONST.PRIMARY_SERVER) {
                    // Retry request using backup server instead
                    // TODO: May want to lengthen request timeout
                    _sendRequest(url, UBLOX_ASSIST_NOW_CONST.BACKUP_SERVER, cb);
                    return;
                }

                // If we have tried both servers, and we don't have a better error message, create
                // an error message from the response body.
                if (err == null) err = "Error: status code = " + status + ", msg = " + resp.body;
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
                    encoded += (v + ";");
                    break;
                case "float":
                    // Use format, so float isn't truncated
                    encoded += format("%f;", v);
                    break;
                case "array":
                    local last = v.len() - 1;
                    foreach(idx, item in v) {
                        encoded += (idx == last) ? (item + ";") : (item + ",");
                    }
                    break;
                default:
                    // Data could not be formatted
                    return null;
            }
        }
        return encoded;
    }
}