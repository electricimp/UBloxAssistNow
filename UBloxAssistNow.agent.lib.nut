// https://www.u-blox.com/sites/default/files/products/documents/MultiGNSS-Assistance_UserGuide_%28UBX-13004360%29.pdf
// MGA access tokens - http://www.u-blox.com/services-form.html
class UBloxAssistNow {

    _token   = null;
    _headers = null;

    constructor(token) {
        const UBLOX_ASSISTNOW_ONLINE_URL     = "https://online-%s.services.u-blox.com/GetOnlineData.ashx";
        const UBLOX_ASSISTNOW_OFFLINE_URL    = "https://offline-%s.services.u-blox.com/GetOfflineData.ashx";
        const UBLOX_ASSISTNOW_PRIMARY_SERVER = "live1";
        const UBLOX_ASSISTNOW_BACKUP_SERVER  = "live2";

        _token   = token;
        _headers = {};
    }

    function setHeaders(headers) {
        _headers = headers;
    }

    function online(reqParams, cb) {
        local url = format("%s?token=%s;%s",
                      UBLOX_ASSISTNOW_ONLINE_URL, _token, _formatOptions(reqParams));
        _sendRequest(url, UBLOX_ASSISTNOW_PRIMARY_SERVER, cb);
    }

    function offline(reqParams, cb) {
        local url = format("%s?token=%s;%s",
                      UBLOX_ASSISTNOW_OFFLINE_URL, _token, _formatOptions(reqParams));
        _sendRequest(url, UBLOX_ASSISTNOW_PRIMARY_SERVER, cb);
    }

    function _sendRequest(url, svr, cb) {
        local req = http.get(format(url, svr), _headers);
        req.sendasync(_respFactory(svr));
    }

    function _respFactory(url, svr, cb) {
        // Return a process response function
        return function(resp) {
            local status = resp.statuscode;
            local err = null;

            if (status == 403) {
                err = "ERROR: Overload limit reached.";
            } else if (status < 200 || status >= 300) {
                if (svr == UBLOX_ASSISTNOW_PRIMARY_SERVER) {
                    // Retry request using backup server instead
                    // TODO: May want to lengthen request timeout
                    _sendRequest(url, UBLOX_ASSISTNOW_BACKUP_SERVER, cb);
                    return;
                }
                // Body should contain an error message string
                err = resp.body;
            }

            cb(err, resp);
        }.bindenv(this);
    }

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