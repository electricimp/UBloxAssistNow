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
@include "github:electricimp/UBloxM8N/Driver/UBloxM8N.device.lib.nut"

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

    function _checkMonVer(resolve) {
        if (!assist._gpsReady) {
            imp.wakeup(0.5, function() {
                _checkMonVer(resolve);
            }.bindenv(this))
        } else {
            // check payload
            local monVer = assist.getMonVer();

            if (processTimer != null) {
                imp.cancelwakeup(processTimer);
                processTimer = null;
            }

            assertTrue(typeof monVer == "blob");
            assertTrue(monVer.len() >= 40);

            return resolve("getMonVer returned expected payload");
        }
    }

    function _ubxProcessor() {
        local writeData = uart.getWriteBuffer();
        info(typeof writeData);
        switch(writeData) {
            case "\xb5\x62\x0a\x04\x00\x00\x0e\x34":
                uart.setAsyncReadBuffer("\xb5\x62\x0a\x04\x64\x00\x32\x2e\x30\x31\x20\x28\x37\x35\x33\x33\x31\x29\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x30\x30\x30\x38\x30\x30\x30\x30\x00\x00\x50\x52\x4f\x54\x56\x45\x52\x20\x31\x35\x2e\x30\x30\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x47\x50\x53\x3b\x53\x42\x41\x53\x3b\x47\x4c\x4f\x3b\x42\x44\x53\x3b\x51\x5a\x53\x53\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80\x29");
                break;
            case "\xb5\x62\x06\x23\x28\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x56\x24":
                uart.setAsyncReadBuffer("\xb5\x62\x05\x01\x02\x00\x06\x23\x31\x5a");
                break;
        }
        processTimer = imp.wakeup(0, _ubxProcessor.bindenv(this));
    }

    function setUp() {
        // Configure ubx
        // stubbed uart??
        uart = StubbedUart();
        ubx = UBloxM8N(uart);
        assist = UBloxAssistNow(ubx);

        return "SetUp complete";
    }

    function testGetMonVer() {
        _ubxProcessor();
        return Promise(function(resolve, reject) {
            _checkMonVer(resolve);
            imp.wakeup(5, function() {
                if (processTimer != null) {
                    imp.cancelwakeup(processTimer);
                    processTimer = null;
                }
                return reject("getMonVer test timed out: GPS not ready");
            }.bindenv(this))
        }.bindenv(this));
    }

    function testGetMgaAck() {

    }

    function testGetDateString() {}

    function testWriteAssistNow() {}

    function testWriteUtcTimeAssist() {}



    function testInit() {}

    function testMgaAckMsgHandler() {}

    function testMonVerMsgHandler() {}

    function testWriteAssist() {}

    function testGetCfgNavx5MsgVersion() {}

    function testMgaAckValid() {
        // binary: 01 00 00 06 02 00 18 00
        // Tests all fields are present and are expected type & value
        local payload = _createPayload(UBX_VALID_MGA_ACK);
        local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.MGA_ACK](payload);

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
        // local error = format(UbxMsgParser.ERROR_PARSING, "");

        assertTrue(crypto.equals(payload, parsed.payload), TEST_ERROR_MSG.PAYLOAD);
        // assertTrue(parsed.error.find(error) != null, TEST_ERROR_MSG.ERROR_MISSING);

        return "Invalid MGA-ACK message returned expected error.";
    }

    function testGetProtVerValid() {}

    function testGetProtVerInvalid() {}

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