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


// Limitations - requests are identified by verb and url, so only one response can be scheduled at a time for each of these requests.
// TODO: Streaming methods not implemented yet (these return original http streaming method)
// httprequest setvalidation only stored in the reqest object, not used otherwise
class StubbedHttp {

    static DEFAULT_REQUEST_TIMER = 1;
    static DEFAULT_SERVER_RESP = {
        "statuscode" : 200,
        "headers" : {},
        "body": ""
    };

    // Preserve original http and http.hash
    _http         = null;
    hash          = null;

    // Class vars
    _pendingReqs  = null;
    _pendingResps = null;
    _requestTime  = null;

    constructor() {
        _http         = http;
        hash          = _http.hash;

        _pendingReqs  = {};
        _pendingResps = {};
        _requestTime  = DEFAULT_REQUEST_TIMER;
    }

    // Keep the same functionality
    // ----------------------------------------------------

    function agenturl() {
        return _http.agenturl();
    }

    function base64decode(d) {
        return _http.base64decode(d);
    }

    function base64encode(d) {
        return _http.base64encode(d);
    }

    function jsondecode(d) {
        return _http.jsondecode(d);
    }

    function jsonencode(d) {
        return _http.jsonencode(d);
    }

    function urldecode(d) {
        return _http.urldecode(d);
    }

    function urlencode(d) {
        return _http.urlencode(d);
    }

    function onrequest(cb) {
        _http.jsonencode(cb);
    }

    // Overwrite the functions that return request objects
    // ----------------------------------------------------

    function get(url, headers) {
        return request("GET", url, headers);
    }

    function httpdelete(url, headers) {
        return request("DELETE", url, headers);
    }

    function post(URL, headers, body) {
        return request("POST", url, headers, body);
    }

    function poststream(URL, headers, cb) {
        // TODO: Create httpstream object
        return _http.poststream(URL, headers, cb);
    }

    function put(URL, headers, body) {
        return request("PUT", url, headers, body);
    }

    function putstream(URL, headers, cb) {
        // TODO: Create httpstream object
        return _http.putstream(URL, headers, cb);
    }

    // Creates a request with stored response for that verb/url or a default response
    function request(verb, url, headers, body = null) {
        local key = getReqKey(verb, url);
        local resp = (key in _pendingResps) ? _pendingResps[key] : DEFAULT_SERVER_RESP;
        local req = StubbedHttpRequest(verb, url, headers, body, resp, _requestTime);
        // Store request/response locally
        _pendingReqs[key] <- req;
        _pendingResps[key] <- resp;
        return req;
    }

    function requeststream(verb, URL, headers, cb) {
        // TODO: Create httpstream object
        return _http.requeststream(verb, URL, headers, cb);
    }

    // Custom functions
    // ----------------------------------------------------

    function getReqKey(verb, url) {
        return format("%s_%s", verb, url);
    }

    function setServerResponseFor(verb, url, resp) {
        local key = getReqKey(verb, url);
        _pendingResps[key] <- resp;
        if (key in _pendingReqs) _pendingReqs[keys].setServerResponse(resp);
    }

    function triggerStreamDataFor(verb, url, data, interval = null) {
        local key = getReqKey(verb, url);
        if (key in _pendingReqs) {
            _pendingReqs[key].triggerStreamData(data, interval);
            return true;
        }
        return false;
    }

    function getPendingResponses() {
        return _pendingResps;
    }

    function getPendingRequests() {
        return _pendingReqs;
    }

    // Clears all stored pending responses
    function clearPendingResponses() {
        _pendingResps.clear();
    }

    // Cancels all pending requests and clears all stored
    function clearPendingRequests() {
        foreach(req in _pendingReqs) {
            req.cancel();
        }
        _pendingReqs.clear();
    }

    // Clears all pending requests and responses
    function clearPending() {
        clearPendingResponses();
        clearPendingRequests();
    }

    // Timeout before response data is returned. This is the same for all
    // requests. If updated, update will only effect requests created after
    // the change.
    function setRequestTimer(sec) {
        _requestTime = sec;
    }

}

// Note - this class doesn't overwrite the imp API httprequest object. The StubbedHttp returns these instances instead of imp API httprequest
class StubbedHttpRequest {

    verb         = null;
    url          = null;
    headers      = null;
    body         = null;
    active       = null;
    _svrResp     = null;
    _streamCB    = null;
    _validation  = null;
    _requstTimer = null;

    // Original 4 params, and 2 params for testing
    constructor(_verb, _url, _headers, _body = null, response = null, reqTmr = null) {
        verb    = _verb.toupper();
        url     = _url;
        headers = _headers;
        body    = _body;
        active  = true;
        _svrResp = response;
        _requstTimer = reqTmr;
    }

    function cancel() {
        active = false;
    }

    function sendasync(onDone, streamingCb = null, timeout = 600) {
        _streamCB = streamingCb;
        local timer = (_streamCB != null) ? timeout : _requstTimer;

        imp.wakeup(timer, function() {
            if (active) onDone(_svrResp);
            active = null;
        }.bindenv(this))
    }

    function sendsync() {
        imp.sleep(_requstTimer);
        active = null;
        return serverResp;
    }

    function setvalidation(validation) {
        // TODO: implement usage of validation in request
        _validation = validation;
    }

    // Custom functions - these will likely be triggered from HTTP base class custom functions unless requests are bubbled up.

    function setServerResponse(response) {
        _svrResp = response;
    }

    function triggerStreamData(data, interval = null) {
        if (_streamCB == null || !active) return;

        if (interval == null) {
            _streamCB(data);
            return;
        }

        imp.wakeup(interval, function() {
            if (active) {
                _streamCB(data);
                triggerStreamData(data, interval);
            }
        }.bindenv(this))
    }

    function setRequestTimer(time) {
        _requstTimer = time;
    }

}