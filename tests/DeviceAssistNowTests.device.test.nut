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


@include __PATH__+"/../DeviceLibrary/UBloxAssistNow.device.lib.nut"
@include __PATH__+"/../tests/StubbedUart.device.nut"
@include "github:electricimp/UBloxM8N/Driver/UBloxM8N.device.lib.nut@develop"

// test for mgsAck parser
const UBX_VALID_MGA_ACK = "\x01\x00\x00\x06\x02\x00\x18\x00";
const UBX_INVALID_MGA_ACK = "z";

enum TEST_ERROR_MSG {
    PAYLOAD = "Parsed payload did not match original.",
    UNEXPECTED_FIELD_TYPE = "Unexpected %s field type.",
    UNEXPECTED_FIELD_VAL = "Unexpected %s field value.",
    ERROR_NOT_NULL = "Error was not null.",
    ERROR_MISSING = "No error message found."
}

class DeviceAssistNowTests extends ImpTestCase {

    assist = null;
    ubx    = null;
    uart   = null;

    processTimer = null;

    function _createPayload(msg) {
        local b = blob(msg.len());
        b.writestring(msg);
        return b;
    }

    function _ubxProcessor(done) {
        local writeData = uart.getWriteBuffer();
        if (writeData.len() > 0) {
            info("Found write data...");
            info(writeData.len());
        }
        switch(writeData) {
            case "\xb5\x62\x0a\x04\x00\x00\x0e\x34":
                uart.clearWriteBuffer();
                uart.setAsyncReadBuffer("\xb5\x62\x0a\x04\x64\x00\x32\x2e\x30\x31\x20\x28\x37\x35\x33\x33\x31\x29\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x30\x30\x30\x38\x30\x30\x30\x30\x00\x00\x50\x52\x4f\x54\x56\x45\x52\x20\x31\x35\x2e\x30\x30\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x47\x50\x53\x3b\x53\x42\x41\x53\x3b\x47\x4c\x4f\x3b\x42\x44\x53\x3b\x51\x5a\x53\x53\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80\x29");
                break;
            case "\xb5\x62\x06\x23\x28\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x56\x24":
                uart.clearWriteBuffer();
                uart.setAsyncReadBuffer("\xb5\x62\x05\x01\x02\x00\x06\x23\x31\x5a");
                imp.wakeup(0.5, done.bindenv(this));
                break;
        }
        processTimer = imp.wakeup(0.01, function() {
            _ubxProcessor(done);
        }.bindenv(this));
    }

    function _cancelProcessTimer() {
        if (processTimer != null) {
            imp.cancelwakeup(processTimer);
            processTimer = null;
        }
    }

    function setUp() {
        // Configure ubx with Stubbed UART
        uart = StubbedUart();
        ubx = UBloxM8N(uart);
        assist = UBloxAssistNow(ubx);

        // SetUp UART responses for assist now init
        return Promise(function(resolve, reject) {
            _ubxProcessor(function() {
                _cancelProcessTimer();
                uart.clearReadBuffer();
                uart.clearWriteBuffer();
                return resolve("SetUp complete");
            }.bindenv(this));
            imp.wakeup(10, function() {
                _cancelProcessTimer();
                uart.clearReadBuffer();
                uart.clearWriteBuffer();
                return reject("SetUp timed out");
            }.bindenv(this))
        }.bindenv(this))
    }

    function testGetMonVer() {
        local monVer = assist.getMonVer();
        assertTrue(typeof monVer == "blob");
        assertTrue(monVer.len() >= 40);
        return "getMonVer returned expected result";
    }

    function testGetDateString() {
        // Date table
        local d = {
            "min": 36,
            "hour": 21,
            "day": 8,
            "year": 2019,
            "wday": 5,
            "time": 1549661801,
            "sec": 41,
            "yday": 38,
            "usec": 662446,
            "month": 1
        };
        local expected = "20190208";
        local actual = assist.getDateString(d);
        assertEqual(expected, actual, "getDateString did not return expected result with optional date parameter");
        local now = date();
        expected = format("%04d%02d%02d", d.year, d.month + 1, d.day);
        actual = assist.getDateString(d);
        assertEqual(expected, actual, "getDateString did not return expected result with no parameter");

        return "getDateString returned expected result";
    }

    function testWriteAssistNow() {
        // local assistOfflineMsgs = "\xb5\x62\x13\x20\x4c\x00\x00\x00\x01\x00\x13\x02\x09\x0c\xf7\x07\x70\xfe\x60\xe0\xfd\x3f\x22\xfe\x0f\xd8\x4e\x1a\x00\x0d\x75\xab\xe0\x23\x7e\x11\x25\x30\x0c\xd1\x08\x09\xf3\x8b\xf5\x01\x1f\x18\x97\x0f\x5c\x45\x60\xe0\xa0\x35\xa1\xfa\xc5\x15\x14\x57\x55\xff\x02\x63\xa5\x0c\x24\xdd\xa7\x05\xb3\xff\x21\xf3\x03\x32\x00\x00\x00\x00\xfc\x7d\xb5\x62\x13\x20\x4c\x00\x00\x00\x02\x00\x13\x02\x09\x0c\xf7\x07\x70\xfe\x60\xe0\xfd\x3f\x48\xfd\x0f\xd8\x23\xc5\x80\xf0\x75\xab\xe0\xe3\x7e\x11\x85\x60\x50\x6d\x08\x09\x17\x30\xf7\x16\x1f\x18\x97\x0f\x5c\x45\x60\xe0\x22\x9e\x3a\x9b\xfd\x19\xfc\xf7\x3b\x75\x0a\xd7\xab\x72\x04\x1f\xa2\xa8\xc3\x30\xaf\xb9\x88\xea\x00\x00\x00\x00\xd4\x0e";

        //     "\xb5\x62\x13\x20\x4c\x00\x00\x01\x01\x00\x13\x02\x09\x0c\xf7\x07\x70\xfe\x60\xe0\xfd\x3f\x22\xfe\x0f\xd8\x4e\x1a\x00\x0d\x75\xab\xe0\x23\x7e\x11\x25\x30\x0c\xd1\x08\x09\xf3\x8b\xf5\x01\x1f\x18\x97\x0f\x5c\x45\x60\xe0\xa0\x35\xa1\xfa\xc5\x15\x14\x57\x55\xff\x02\x63\xa5\x0c\x24\xdd\xa7\x05\xb3\xff\x21\xf3\x03\x32\x00\x00\x00\x00\xfc\x7d\xb5\x62\x13\x20\x4c\x00\x00\x00\x02\x00\x13\x02\x09\x0c\xf7\x07\x70\xfe\x60\xe0\xfd\x3f\x48\xfd\x0f\xd8\x23\xc5\x80\xf0\x75\xab\xe0\xe3\x7e\x11\x85\x60\x50\x6d\x08\x09\x17\x30\xf7\x16\x1f\x18\x97\x0f\x5c\x45\x60\xe0\x22\x9e\x3a\x9b\xfd\x19\xfc\xf7\x3b\x75\x0a\xd7\xab\x72\x04\x1f\xa2\xa8\xc3\x30\xaf\xb9\x88\xea\x00\x00\x00\x00\xd4\x0e";

        // Write one valid assist now packet & one invalid assist now packet
        // write buffer -> trigger read buffer with resp
        // Check onDone -> error table
    }

    function testWriteUtcTimeAssist() {
        local validYear = 2019;
        local invalidYear = 1975;

        uart.clearReadBuffer();
        uart.clearWriteBuffer();

        assertTrue(assist.writeUtcTimeAssist(validYear), "writeUtcTimeAssist with valid year returned unexpected value");
        local expectedTimeAssistPayloadStart = "\xb5\x62\x13\x40\x18\x00\x10";
        local buff = uart.getWriteBuffer();
        assertEqual(32, buff.len(), "writeUtcTimeAssist with valid year didn't write to uart");
        assertTrue(buff.find(expectedTimeAssistPayloadStart) != null, "writeUtcTimeAssist write buffer did not included expected payload start");

        uart.clearReadBuffer();
        uart.clearWriteBuffer();

        assertTrue(!assist.writeUtcTimeAssist(invalidYear), "writeUtcTimeAssist with invalid year returned unexpected value");
        buff = uart.getWriteBuffer();
        assertEqual(0, buff.len(), "writeUtcTimeAssist with valid year wrote to uart");

        uart.clearReadBuffer();
        uart.clearWriteBuffer();

        return "writeUtcTimeAssist returns expected results";
    }

    function testMonVerMsgHandlerInvalidProtoVer() {
        try {
            local payload = "\xb5\x62\x0a\x04\x64\x00\x32\x2e\x30\x31\x20\x28\x37\x35\x33\x33\x31\x29\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x30\x30\x30\x38\x30\x30\x30\x30\x00\x00\x80\x29";
            assist._monVerMsgHandler(_createPayload(payload));
        } catch(e) {
            local expected = "Error: Initialization failed. Protocol version not found.";
            assertEqual(expected, e, "Payload missing PROTVER returned unexpected error.");
        }
        return "MonVerMsgHandler with MON-VER payload missing PROTVER throws expected error";
    }

    function testGetCfgNavx5MsgVersion() {
        local invalid = assist._getCfgNavx5MsgVersion("12.00");
        local ver0 = assist._getCfgNavx5MsgVersion("15.00");
        local ver2 = assist._getCfgNavx5MsgVersion("20.01");
        local ver3 = assist._getCfgNavx5MsgVersion("19.20");

        assertEqual(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_0, ver0, "version 0 string returned unexpected integer");
        assertEqual(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_2, ver2, "version 2 string returned unexpected integer");
        assertEqual(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_3, ver3, "version 3 string returned unexpected integer");
        assertEqual(null, invalid, "invalid version returned unexpected value");

        return "getCfgNavx5MsgVersion test passed.";
    }

    function testMgaAckValid() {
        // binary: 01 00 00 06 02 00 18 00
        // Tests all fields are present and are expected type & value
        local payload = _createPayload(UBX_VALID_MGA_ACK);
        local parsed = assist._parseMgaAck(payload);

        assertTrue(crypto.equals(payload, parsed.payload), TEST_ERROR_MSG.PAYLOAD);
        assertEqual(null, parsed.error, TEST_ERROR_MSG.ERROR_NOT_NULL);

        assertTrue("type" in parsed && (typeof parsed.type == "integer"), format(TEST_ERROR_MSG.UNEXPECTED_FIELD_TYPE, "type"));
        assertEqual(0x01, parsed.type, format(TEST_ERROR_MSG.UNEXPECTED_FIELD_VAL, "type"));

        assertTrue("version" in parsed && (typeof parsed.version == "integer"), format(TEST_ERROR_MSG.UNEXPECTED_FIELD_TYPE, "version"));
        assertEqual(0x00, parsed.version, format(TEST_ERROR_MSG.UNEXPECTED_FIELD_VAL, "version"));

        assertTrue("infoCode" in parsed && (typeof parsed.infoCode == "integer"), format(TEST_ERROR_MSG.UNEXPECTED_FIELD_TYPE, "infoCode"));
        assertEqual(0x00, parsed.infoCode, format(TEST_ERROR_MSG.UNEXPECTED_FIELD_VAL, "infoCode"));

        assertTrue("msgId" in parsed && (typeof parsed.msgId == "integer"), format(TEST_ERROR_MSG.UNEXPECTED_FIELD_TYPE, "msgId"));
        assertEqual(0x06, parsed.msgId, format(TEST_ERROR_MSG.UNEXPECTED_FIELD_VAL, "msgId"));

        assertTrue("msgPayloadStart" in parsed && (typeof parsed.msgPayloadStart == "blob"), format(TEST_ERROR_MSG.UNEXPECTED_FIELD_TYPE, "msgPayloadStart"));
        assertTrue(crypto.equals("\x02\x00\x18\x00", parsed.msgPayloadStart), format(TEST_ERROR_MSG.UNEXPECTED_FIELD_VAL, "msgPayloadStart"));

        return "Valid MGA-ACK message parse test passed.";
    }

    function testMgaAckInvalid() {
        local payload = _createPayload(UBX_INVALID_MGA_ACK);
        local parsed = assist._parseMgaAck(payload);
        local error = "Error: Could not parse payload";

        assertTrue(crypto.equals(payload, parsed.payload), TEST_ERROR_MSG.PAYLOAD);
        assertTrue(parsed.error.find(error) != null, TEST_ERROR_MSG.ERROR_MISSING);

        return "Invalid MGA-ACK message returned expected error.";
    }

    function testGetProtVerValid() {
        local payload = "\xb5\x62\x0a\x04\x64\x00\x32\x2e\x30\x31\x20\x28\x37\x35\x33\x33\x31\x29\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x30\x30\x30\x38\x30\x30\x30\x30\x00\x00\x50\x52\x4f\x54\x56\x45\x52\x20\x31\x35\x2e\x30\x30\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x47\x50\x53\x3b\x53\x42\x41\x53\x3b\x47\x4c\x4f\x3b\x42\x44\x53\x3b\x51\x5a\x53\x53\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80\x29";
        local expected = "15.00";
        local actual = assist._getProtVer(_createPayload(payload));
        assertEqual(expected, actual, "protocol version parser returned unectpected value");

        return "getProtVer with valid payload returned expected results";
    }

    function testGetProtVerInvalid() {
        try {
            local payload = "\xb5\x62\x0a\x04\x64\x00\x32\x2e\x30\x31\x20\x28\x37\x35\x33\x33\x31\x29\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x30\x30\x30\x38\x30\x30\x30\x30\x00\x00\x80\x29";
            local actual = assist._getProtVer(_createPayload(payload));
        } catch(e) {
            local expected = "Error: Initialization failed. Protocol version not found.";
            assertEqual(expected, e, "Payload missing PROTVER returned unexpected error.");
        }

        try {
            local payload = "invalidPayload";
            local actual = assist._getProtVer(payload);
        } catch(e) {
            local expected = "Error: Initialization failed. Protocol version parsing error: the index 'seek' does not exist";
            assertTrue(e.find(expected) != null, "Invalid payload returned unexpected parsing error.");
        }

        return "getProtVer with invalid payloads returned expected results";
    }

}



// Configuring u-blox...
// Writing...
// $PUBX,41,1,0001,0001,9600,0*14

// Writing...
// binary: b5 62 06 00 14 00 01 00 00 00 c0 08 00 00 80 25 00 00 01 00 01 00 00 00 00 00 8a 79
// Writing...
// binary: b5 62 06 00 14 00 01 00 00 00 c0 08 00 00 00 c2 01 00 01 00 01 00 00 00 00 00 a8 42

// Initializing Assist Now...
// Writing...
// binary: b5 62 0a 04 00 00 0e 34
// Received...
// binary: b5 62 0a 04 64 00 32 2e 30 31 20 28 37 35 33 33 31 29 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 30 30 30 38 30 30 30 30 00 00 50 52 4f 54 56 45 52 20 31 35 2e 30 30 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 47 50 53 3b 53 42 41 53 3b 47 4c 4f 3b 42 44 53 3b 51 5a 53 53 00 00 00 00 00 00 00 00 00 80 29
// Writing...
// binary: b5 62 06 23 28 00 00 00 00 04 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 56 24
// Received...
// binary: b5 62 05 01 02 00 06 23 31 5a
// In ubx msg handler...
// --------------------------------------------
// Msg Class ID: 0x0501
// Msg len: 2
// error: (null : 0x0)
// ackMsgClassId: 1571
// payload: 0x06 0x23
// --------------------------------------------



//    "*.test.nut",
//    "tests/**/*.test.nut"