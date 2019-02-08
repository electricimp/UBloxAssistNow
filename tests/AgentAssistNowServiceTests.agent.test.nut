// MIT License

// Copyright 2019 Electric Imp

// SPDX-License-Identifier: MIT

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

@include __PATH__+"/../AgentLibrary/UBloxAssistNow.agent.lib.nut"

const U_BLOX_INVALID_AUTH_TOKEN = "_UBLOX_AUTH_TOKEN_";
const U_BLOX_AUTH_TOKEN         = "@{U_BLOX_AUTH_TOKEN}";

// The library uses these to parse response data
// Confirm these values are returned from Assist Now
const STATUS_CODE_SUCCESS        = 200;
const STATUS_CODE_FAIL           = 400;
const REQUEST_FAIL_BODY          = "Bad Request";
const HEADER_KEY_INVALID_TOKEN   = "http/1.1 400 invalid token";
const HEADER_KEY_INVALID_PARAM   = "http/1.1 400 invalid parameter";
const INVALID_PARAM_KEY          = "notGonnaWork";
const BODY_MSG_HEADER            = "\xb5\x62";
const ONLINE_BODY_MSG_CLASS_ID   = "\x13\x40";
const OFFLINE_BODY_MSG_CLASS_ID  = "\x13\x20";

const ASYNC_TEST_TIMEOUT        = 5;

// These tests are meant to confirm that the response data from AssistNow services conforms to
// expectations.
class AgentAssistNowServiceTests extends ImpTestCase {

    assist = null;

    function setUp() {
        // Configure with valid token
        assist = UBloxAssistNow(U_BLOX_AUTH_TOKEN);

        return "SetUp complete";
    }

    function testOnlineAssistInvalidToken() {
        // Use an invalid token for this test
        local invalidAssist = UBloxAssistNow(U_BLOX_INVALID_AUTH_TOKEN);

        // Request Params
        local assistOnlineParams = {
            "gnss"     : ["gps", "glo"],
            "datatype" : ["eph", "alm", "aux"]
        }

        return Promise(function(resolve, reject) {
            // Configure request callback
            local onDone = function(err, resp) {
                // Check for expected response
                assertEqual(UBLOX_ASSIST_NOW_CONST.ERROR_REQ_INVALID_TOKEN, err, "requestOnline response returned an unexpected error");
                assertEqual(STATUS_CODE_FAIL, resp.statuscode, "requestOnline response returned an unexpected status code");
                assertTrue("headers" in resp, "requestOnline response missing headers");
                assertTrue(HEADER_KEY_INVALID_TOKEN in resp.headers, "requestOnline response header did not contain expected invalid token string");

                return resolve("requestOnline with invalid token test succeeded");
            }

            // Send online request
            invalidAssist.requestOnline(assistOnlineParams, onDone.bindenv(this));

            // Configure test fail timeout
            imp.wakeup(ASYNC_TEST_TIMEOUT, function() {
                return reject("requestOnline with invalid token test timed out");
            }.bindenv(this));
        }.bindenv(this))
    }

    function testOfflineAssistInvalidToken() {
        // Use an invalid token for this test
        local invalidAssist = UBloxAssistNow(U_BLOX_INVALID_AUTH_TOKEN);

        // Request Params
        local assistOfflineParams = {
            "gnss"       : ["gps", "glo"],
            "period"     : 1,
            "days"       : 3
        }

        return Promise(function(resolve, reject) {
            // Configure request callback
            local onDone = function(err, resp) {
                // Check for expected response
                assertEqual(UBLOX_ASSIST_NOW_CONST.ERROR_REQ_INVALID_TOKEN, err, "requestOffline response returned an unexpected error");
                assertEqual(STATUS_CODE_FAIL, resp.statuscode, "requestOffline response returned an unexpected status code");
                assertTrue("headers" in resp, "requestOffline response missing headers");
                assertTrue(HEADER_KEY_INVALID_TOKEN in resp.headers, "requestOffline response header did not contain expected invalid token string");

                return resolve("requestOffline with invalid token test succeeded");
            }

            // Send online request
            invalidAssist.requestOffline(assistOfflineParams, onDone.bindenv(this));

            // Configure test fail timeout
            imp.wakeup(ASYNC_TEST_TIMEOUT, function() {
                return reject("requestOffline with invalid token test timed out");
            }.bindenv(this));
        }.bindenv(this))
    }

    function testOnlineAssistInvalidParam() {
        // Request Params
        local assistOnlineParams = {
            "gnss"       : ["gps", "glo"],
            "datatype"   : ["eph", "alm", "aux"]
        }

        // Add Bad Key
        assistOnlineParams[INVALID_PARAM_KEY] <- "xxx";
        local expectedHeaderValue = format("'%s'", INVALID_PARAM_KEY);

        return Promise(function(resolve, reject) {
            // Configure request callback
            local onDone = function(err, resp) {
                // Check for expected response
                assertEqual(format(UBLOX_ASSIST_NOW_CONST.ERROR_REQ_INVALID_PARAM, expectedHeaderValue), err, "requestOnline response returned an unexpected error");
                assertEqual(STATUS_CODE_FAIL, resp.statuscode, "requestOnline response returned an unexpected status code");
                assertTrue("headers" in resp, "requestOnline response missing headers");
                assertTrue(HEADER_KEY_INVALID_PARAM in resp.headers, "requestOnline response header did not contain expected invalid param string");
                assertEqual(resp.headers[HEADER_KEY_INVALID_PARAM], expectedHeaderValue, "requestOnline response header did not contain expected invalid param value");

                return resolve("requestOnline with invalid param test succeeded");
            }

            // Send online request
            assist.requestOnline(assistOnlineParams, onDone.bindenv(this));

            // Configure test fail timeout
            imp.wakeup(ASYNC_TEST_TIMEOUT, function() {
                return reject("requestOnline with invalid param test timed out");
            }.bindenv(this));
        }.bindenv(this))
    }

    function testOfflineAssistInvalidParam() {
        // Request Params
        local assistOfflineParams = {
            "gnss"       : ["gps", "glo"],
            "period"     : 1,
            "days"       : 3
        }

        // Add Bad Key
        assistOfflineParams[INVALID_PARAM_KEY] <- "xxx";
        local expectedHeaderValue = format("'%s'", INVALID_PARAM_KEY);

        return Promise(function(resolve, reject) {
            // Configure request callback
            local onDone = function(err, resp) {
                // Check for expected response
                assertEqual(format(UBLOX_ASSIST_NOW_CONST.ERROR_REQ_INVALID_PARAM, expectedHeaderValue), err, "requestOffline response returned an unexpected error");
                assertEqual(STATUS_CODE_FAIL, resp.statuscode, "requestOffline response returned an unexpected status code");
                assertTrue("headers" in resp, "requestOffline response missing headers");
                assertTrue(HEADER_KEY_INVALID_PARAM in resp.headers, "requestOffline response header did not contain expected invalid param string");
                assertEqual(resp.headers[HEADER_KEY_INVALID_PARAM], expectedHeaderValue, "requestOffline response header did not contain expected invalid param value");

                return resolve("requestOffline with invalid param test succeeded");
            }

            // Send online request
            assist.requestOffline(assistOfflineParams, onDone.bindenv(this));

            // Configure test fail timeout
            imp.wakeup(ASYNC_TEST_TIMEOUT, function() {
                return reject("requestOffline with invalid param test timed out");
            }.bindenv(this));
        }.bindenv(this))
    }

    function testOnlineAssistSuccessFromMain() {
        // Request Params
        local assistOnlineParams = {
            "gnss"       : ["gps", "glo"],
            "datatype"   : ["eph", "alm", "aux"]
        }

        return Promise(function(resolve, reject) {
            // Configure request callback
            local onDone = function(err, resp) {
                // Check for expected response
                assertEqual(null, err, "requestOnline response returned an unexpected error");
                assertEqual(STATUS_CODE_SUCCESS, resp.statuscode, "requestOnline response returned an unexpected status code");
                assertTrue("body" in resp, "requestOnline response missing body");
                // Check body for ubx packet - header, class-id
                local body = resp.body;
                assertTrue(body.find(BODY_MSG_HEADER) != null, "requestOnline response body did not contain expected UBX header data");
                assertTrue(body.find(ONLINE_BODY_MSG_CLASS_ID) != null, "requestOnline response body did not contain expected UBX class-id data");

                return resolve("requestOnline with invalid param test succeeded");
            }

            // Send online request
            assist.requestOnline(assistOnlineParams, onDone.bindenv(this));

            // Configure test fail timeout
            imp.wakeup(ASYNC_TEST_TIMEOUT, function() {
                return reject("requestOnline with invalid param test timed out");
            }.bindenv(this));
        }.bindenv(this))
    }

    function testOnlineAssistSuccessFromBackUp() {
        // Request Params
        local assistOnlineParams = {
            "gnss"       : ["gps", "glo"],
            "datatype"   : ["eph", "alm", "aux"]
        }

        return Promise(function(resolve, reject) {
            // Configure request callback
            local onDone = function(err, resp) {
                // Check for expected response
                assertEqual(null, err, "online backup server response returned an unexpected error");
                assertEqual(STATUS_CODE_SUCCESS, resp.statuscode, "online backup server response returned an unexpected status code");
                assertTrue("body" in resp, "online backup server response missing body");
                // Check body for ubx packet - header, class-id
                local body = resp.body;
                assertTrue(body.find(BODY_MSG_HEADER) != null, "online backup server response body did not contain expected UBX header data");
                assertTrue(body.find(ONLINE_BODY_MSG_CLASS_ID) != null, "online backup server response body did not contain expected UBX class-id data");

                return resolve("online backup server with invalid param test succeeded");
            }

            // Use library private send method to test backup server
            local url = format("%s?token=%s;%s", UBLOX_ASSIST_NOW_CONST.ONLINE_URL, U_BLOX_AUTH_TOKEN, assist._formatOptions(assistOnlineParams));
            assist._sendRequest(url, UBLOX_ASSIST_NOW_CONST.BACKUP_SERVER, onDone.bindenv(this));

            // Configure test fail timeout
            imp.wakeup(ASYNC_TEST_TIMEOUT, function() {
                return reject("online backup server test timed out");
            }.bindenv(this));
        }.bindenv(this))
    }

    function testOfflineAssistSuccessFromMain() {
        // Request Params
        local assistOfflineParams = {
            "gnss"       : ["gps", "glo"],
            "period"     : 1,
            "days"       : 3
        }

        return Promise(function(resolve, reject) {
            // Configure request callback
            local onDone = function(err, resp) {
                // Check for expected response
                assertEqual(null, err, "requestOffline response returned an unexpected error");
                assertEqual(STATUS_CODE_SUCCESS, resp.statuscode, "requestOffline response returned an unexpected status code");
                assertTrue("body" in resp, "requestOffline response missing body");
                // Check body for ubx packet - header, class-id, year, month, day
                local body = resp.body;
                assertTrue(body.find(BODY_MSG_HEADER) != null, "requestOffline response body did not contain expected UBX header data");
                local idx = body.find(OFFLINE_BODY_MSG_CLASS_ID);
                assertTrue(idx != null, "requestOffline response body did not contain expected UBX class-id data");
                local actualYear = body[idx + 8];
                local actualMonth = body[idx + 9];
                local actualDay = body[idx + 10];

                local today = date();
                local expectedYear = today.year - 2000;
                local expectedMonth = today.month + 1;
                local expectedDay = today.day;

                // Make sure date data makes sense (don't worry about time date math)
                assertTrue(actualYear == expectedYear || actualYear == expectedYear + 1);
                assertTrue(actualMonth == expectedMonth || actualMonth == expectedMonth + 1);
                // Only check day if it isn't going to wrap around a month
                if (expectedDay < (28 -  assistOfflineParams.days)) {
                    assertTrue(actualDay >= expectedDay && actualDay <= expectedDay + assistOfflineParams.days);
                }

                return resolve("requestOffline with invalid param test succeeded");
            }

            // Send online request
            assist.requestOffline(assistOfflineParams, onDone.bindenv(this));

            // Configure test fail timeout
            imp.wakeup(ASYNC_TEST_TIMEOUT, function() {
                return reject("requestOffline with invalid param test timed out");
            }.bindenv(this));
        }.bindenv(this))
    }

    function testOfflineAssistSuccessFromBackUp() {
        // Request Params
        local assistOfflineParams = {
            "gnss"       : ["gps", "glo"],
            "period"     : 1,
            "days"       : 3
        }

        return Promise(function(resolve, reject) {
            // Configure request callback
            local onDone = function(err, resp) {
                // Check for expected response
                assertEqual(null, err, "requestOffline response returned an unexpected error");
                assertEqual(STATUS_CODE_SUCCESS, resp.statuscode, "requestOffline response returned an unexpected status code");
                assertTrue("body" in resp, "requestOffline response missing body");
                // Check body for ubx packet - header, class-id, year, month, day
                local body = resp.body;
                assertTrue(body.find(BODY_MSG_HEADER) != null, "requestOnline response body did not contain expected UBX header data");
                local idx = body.find(OFFLINE_BODY_MSG_CLASS_ID);
                assertTrue(idx != null, "requestOnline response body did not contain expected UBX class-id data");
                local actualYear = body[idx + 8];
                local actualMonth = body[idx + 9];
                local actualDay = body[idx + 10];

                local today = date();
                local expectedYear = today.year - 2000;
                local expectedMonth = today.month + 1;
                local expectedDay = today.day;

                // Make sure date data makes sense (don't worry about time date math)
                assertTrue(actualYear == expectedYear || actualYear == expectedYear + 1);
                assertTrue(actualMonth == expectedMonth || actualMonth == expectedMonth + 1);
                // Only check day if it isn't going to wrap around a month
                if (expectedDay < (28 -  assistOfflineParams.days)) {
                    assertTrue(actualDay >= expectedDay && actualDay <= expectedDay + assistOfflineParams.days);
                }

                return resolve("requestOffline with invalid param test succeeded");
            }

            // Use library private send method to test backup server
            local url = format("%s?token=%s;%s", UBLOX_ASSIST_NOW_CONST.OFFLINE_URL, U_BLOX_AUTH_TOKEN, assist._formatOptions(assistOfflineParams));
            assist._sendRequest(url, UBLOX_ASSIST_NOW_CONST.BACKUP_SERVER, onDone.bindenv(this));

            // Configure test fail timeout
            imp.wakeup(ASYNC_TEST_TIMEOUT, function() {
                return reject("requestOffline with invalid param test timed out");
            }.bindenv(this));
        }.bindenv(this))
    }

    function tearDown() {
        assist = null;
        return "Test finished";
    }

}