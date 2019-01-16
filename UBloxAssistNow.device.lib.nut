enum UBLOX_ASSIST_NOW_CONST {
    MGA_ACK_CLASS_ID                    = 0x1360,
    MON_VER_CLASS_ID                    = 0x0a04,
    CFG_NAVX5_CLASS_ID                  = 0x0623,

    CFG_NAVX5_MSG_VER_0                 = 0x0000,
    CFG_NAVX5_MSG_VER_2                 = 0x0002,
    CFG_NAVX5_MSG_VER_3                 = 0x0003,

    CFG_NAVX5_MSG_VER_3_LEN             = 44,
    CFG_NAVX5_MSG_VER_0_2_LEN           = 40,

    CFG_NAVX5_MSG_MASK_1_SET_ASSIST_ACK = 0x0400,
    CFG_NAVX5_MSG_ENABLE_ASSIST_ACK     = 0x01
}

//
// manage assist queue, store offline assist info from agent to flash,
// on wake - use assist to help gps get fix faster
class UBloxAssistNow {

    // ublox driver configured for ubx mode - add configure wrapper?
    _ubx = null;
    // SPI Flash File system - store assist files, already initialized with space alocated
    _sffs = null;

    // Assistance messages
    _assist = [];
    // Assist packets sent callback
    _assistDone = null;

    // Flag that tracks if we have refreshed assist offline this boot
    _assistOfflineRefreshed = null;
    _gpsReady = null;
    _monVer = null;

    constructor(ubx, sffs = null) {
        _assistOfflineRefreshed = false;
        _gpsReady = false;

        _ubx  = ubx;
        _sffs = sffs; // required for offline assist
    }

    // register handlers for 0x0a04, and 0x1360, notify user that they should not define a handlers for 1360 or 0x0a04 if using this library - repsonse from 0x0a04 can be retrived using getMonVer function.
    function init() {
        // Register handlers
        _ubx.registerMsgHandler(UBLOX_ASSIST_NOW_CONST.MON_VER_CLASS_ID, function(payload) {
            _monVer = UbxMsgParser[UBLOX_ASSIST_NOW_CONST.MON_VER_CLASS_ID](payload);

            // Do this only on boot
            if (!_gpsReady) {
                _gpsReady = true;
                if ("protver" in _monVer) {
                    local ver = _getCfgNavx5MsgVersion(res.protver);
                    local payload = (ver == UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_3) ? blob(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_3_LEN) : blob(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_VER_0_2_LEN);
                    payload.writen(ver, 'w');
                    // Write mask bits so only ack bits are modified
                    payload.writen(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_MASK_1_SET_ASSIST_ACK, 'w');
                    payload.seek(17, 'b');
                    payload.writen(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_MSG_ENABLE_ASSIST_ACK, 'b');
                    // Enable ACKs for aiding packets
                    ubx.writeUBX(UBLOX_ASSIST_NOW_CONST.CFG_NAVX5_CLASS_ID, payload);
                } else {
                    // TODO :
                    // could not get protver - notify user of error
                }
            }
        });
        _ubx.registerMsgHandler(UBLOX_ASSIST_NOW_CONST.MGA_ACK_CLASS_ID, function(payload) {
            local res = UbxMsgParser[UBLOX_ASSIST_NOW_CONST.MGA_ACK_CLASS_ID](payload);

            // TODO : check for errors!!!
            // {
            //     "type"            : payload.readn('b'),
            //     "version"         : payload.readn('b'),
            //     "infoCode"        : payload.readn('b'),
            //     "msgId"           : payload.readn('b'),
            //     "msgPayloadStart" : payload.readblob(4)
            // }

            // Continue write
            _writeAssist();
        })

        // Test GPS up / get protver
        ubx.writeUBX(UBLOX_ASSIST_NOW_CONST.MON_VER_CLASS_ID, "");
    }

    function getMonVer() {
        return _monVer;
    }

    // pass in msg blob, return bool - if assist has any msgs
    function updateAssist(assistMsgs) {
        if (assistMsgs == null) return false;

        // Split out messages
        while(assistMsgs.tell() < assistMsgs.len()) {
            // Read header & extract length
            local msg = assistMsgs.readstring(6);
            local bodylen = msg[4] | (msg[5] << 8);
            // Read message body & checksum bytes
            local body = assistMsgs.readstring(2 + bodylen);

            // Push message into array
            assist.push(msg+body);
        }

        return (assist.len() > 0);
    }

    // Makes sure GPS is ready then writes locally stored assist data to ubx, registers handler that is triggered when write is done
    function startAssistWrite(onDone) {
        _assistDone = onDone;
        _writeAssist();
    }

    function getPersistedOfflineAssist() {
        // Make filename; offline assist data is valid for the UTC day (ie midpoint is midday UTC)
        // so this is really easy
        local d = date();
        local dayname = format("%04d%02d%02d", d.year, d.month + 1, d.day);

        // Does assist file exist?
        if (!sffs.fileExists(dayname)) return null;

        // Open, then read and split into the assist send queue
        local file = sffs.open(dayname, "r");
        local msgs = file.read();
        file.close();

        return msgs;
    }

    // Stores offline assist from web, organized by date, to SPI
    function persistOfflineAssist(mgaAnoMsgsByDate) {
        // We can only store if we have a valid spi flash storage
        if (_sffs == null) return;

        // Store messages by date
        foreach(day, msgs in mgaAnoMsgsByDate) {
            // If day exists, delete it as new data will be fresher
            if (_sffs.fileExists(day)) {
                _sffs.eraseFile(day);
            }

            // Write day msgs
            local file = _sffs.open(day, "w");
            file.write(msgs);
            file.close();
        }

        // Toggle flag that msgs have been refreshed
        _assistOfflineRefreshed = true;
    }

    function assistOfflineRefreshed() {
        return _assistOfflineRefreshed;
    }

    function _writeAssist() {
        if (!_gpsReady) {
            imp.wakeup(0.5, _writeAssist);
            return;
        }

        if (_assist.len() > 0) {
            // Remove it and send: it's pre-formatted so just dump it to the UART
            local entry = _assist.remove(0);
            _ubx.writeAssist(entry);
            // server.log(format("Sending %02x%02x len %d", entry[2], entry[3], entry.len()));
        } else {
            if (_assistDone) _assistDone();
        }
    }

    function _getCfgNavx5MsgVersion(protver) {
        switch(protver) {
            case "15.00":
            case "15.01":
            case "16.00":
            case "17.00":
                return CFG_NAVX5_MSG_VER_0;
            case "18.00":
            case "19.00":
            case "19.01":
            case "19.20": // Polling will send back v3 message
            case "20.00":
            case "20.01":
            case "20.10":
            case "20.20":
            case "20.30":
            case "22.00":
            case "23.00":
            case "23.01":
                return CFG_NAVX5_MSG_VER_2;
            case "19.10":
            case "19.20":
                return CFG_NAVX5_MSG_VER_3;
        }
        return null;
    }

}