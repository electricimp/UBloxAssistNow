# UBloxAssistNow #

Agent library that retrieves data from u-blox AssistNow servers. Data supplied by the AssistNow Services is used by a u-blox GNSS receiver in order to substantially reduce Time To First Fix, even under poor signal conditions. For information about AssistNow services see this [user guide](https://www.u-blox.com/sites/default/files/products/documents/MultiGNSS-Assistance_UserGuide_%28UBX-13004360%29.pdf)

**To add this library to your project, add** `#require "UBloxAssistNow.agent.lib.nut:1.0.0"` **to the top of your device code.**

## Class Usage ##

## Request Callbacks ##

The methods online() and offline() include a callback parameter. The callback function will be triggered when the response from u-blox AssistNow servers is received. It has two parameters: error and response. If no error was encountered, error will be null. If any error occurred, an error message will be passed to the callback’s error parameter. The response from the server will be passed to the response parameter.

### Constructor: UBloxAssistNow(*token*) ###

To use this service you must register and receive an [authorization token](http://www.u-blox.com/services-form.html).

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *token* | string | Yes | The authorization token supplied by u-blox when a client registers to use the service. |

## Class Methods ##

### online(*reqParams, reqCallback*) ###

If the device is online use this method to get data from the AssistNow Online Service to improve your device's time to first fix. The data provided includes time aiding data, earth orientation parameters and satellite almanacs, ephemerides, and health information. Server side data is updated every 30-60 min.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *reqParams* | table | Yes | Table of request parameters. Can be an empty table. *(see below)* |
| *reqeustCallback* | function | Yes | Function that will be triggered when the response from u-blox AssistNow servers is received. *(see Request Callbacks for details)* |

MGA AssistNow Online parameters:

| Key Name | Possible Values | Default | Type | Description |
| --- | --- | --- | --- | --- |
| *datatype* | eph, alm, aux, pos | N/A | array of strings | The data types required. Time data is always returned for each request (even if this parameter is not supplied) |
| *format* | mga, aid | mga | string | Specifies the format of the data returned (mga = UBXMGA-*
(M8 onwards); aid = UBX-AID-* (u7 or earlier)) |
| *gnss* | gps, qzss, glo, bds, gal | gps| array of strings | GNSS for which data should be returned |
| *lat* | -90 to 90 | N/A | float | Approximate user latitude in WGS 84 in units of degrees
and fractional degrees |
| *lon* | -180 to 180 | N/A | float | Approximate user longitude in WGS 84 in units of
degrees and fractional degrees |
| *alt* | -1000 to 50000 | 0 | float | Approximate user altitude above WGS 84 ellipsoid in
units of meters. |
| *pacc* | 0 to 6000000 | N/A | float | Approximate accuracy of the submitted position in meters |
| *tacc* | 0 to 3600 | N/A | float | The timing accuracy in seconds |
| *latency* | 0 to 3600 | N/A | float | Typical latency in seconds between the time the server receives the request, and the time when the assistance data arrives at the GNSS receiver. |
| *filteronpos* | N/A | N/A | N/A | If present, the ephemeris data returned will only contain data for the satellites which are likely to be visible from the approximate position provided (see lat, lon, alt and pacc parameters). If an approximate position is not provided, no filtering will be performed. |
| *filteronsv* | N/A | N/A | array of strings | An array of u-blox gnssId:svId pairs. The ephemeris data returned will only contain data for the listed satellites. |

#### Return Value ####

None.

### offline(*reqParams, reqCallback*) ###

If the device is likely to have connection issues, when the device is online use this method to download data from the AssistNow Offline Service, specifying the time period (1 to 5 weeks) and the type(s) of GNSS to use so your device can estimate the positions of the satellites when no better data is available. This data will need to be stored in the device's SPI flash and transferred to the u-blox receiver for use. Using these estimates does not provide as accurate a position fix as if current ephemeris data is used, but it allows much faster time to first fix (TTFF) in nearly all cases. The data obtained from the AssistNow Offline Service is organized by date, normally a day at a time. Consequently the more weeks for which coverage is requested, the larger the amount of data to handle. Similarly, each different GNSS requires its own data. In extreme cases, the service may provide several hundred kilobytes of data. This amount can be reduced by requesting a lower resolution, but this has a small negative impact on both position accuracy and TTFF. Server side data is updated every 1-2 times a day.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *reqParams* | table | Yes | Table of request parameters. Must contain "gnss", all other values are optional. *(see below)* |
| *reqeustCallback* | function | Yes | Function that will be triggered when the response from u-blox AssistNow servers is received. *(see Request Callbacks for details)* |

MGA AssistNow Offline parameters:

| Key Name | Possible Values | Default | Type | Description |
| --- | --- | --- | --- | --- |
| *gnss* | gps, glo | N/A | array of strings | The GNSS for which data should be returned. |
| *format* | mga, aid | mga | string | Specifies the format of the data returned (mga = UBX-MGA-* (M8 onwards); aid = UBX-AID-* (u7 or earlier)) |
| *period* | 1, 2, 3, 4, or 5 | 4 | integer | The number of weeks into the future that the data will be valid. Data can be requested for up to 5 weeks into the future. |
| *resolution* | 1, 2, 3 | 1 | integer | The resolution of the data: 1=every day,
2=every other day, 3=every third day |
| *days* | 1, 2, 3, 5, 7, 10, or 14 | 14 | integer | The GNSS for which data should be returned. (Supported on U7 and below) |
| *almanac* | gps, glo, bds, gal, qzss | N/A | array of strings | Added before MGA data is uploaded. (Supported on MGA only) |

#### Return Value ####

None.

### getOfflineMsgByDate(*offlineRes[, logUnknownMsgType]*) ###

Takes the response from the *offline()* and returns a table of assist messages organized by date.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *offlineRes* | HTTP response | Yes | The response parameter returned from *offline()* |
| *logUnknownMsgType* | bool | No | If `true` logs the message class-id if it is not an MGA-ANO message. Defaults to `false`. |

#### Return Value ####

Table. Keys are date strings, values are string of all messages for that date.

### setHeaders(*headers*) ###

By default there are no requests headers set. Use this method to update request headers.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *headers* | table | Yes | Table of HTTP headers. |

#### Return Value ####

None.