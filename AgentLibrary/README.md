# UBloxAssistNow 1.0.0 (Agent) #

This is the agent library used to retrieve data from the u-blox AssistNow web service. Data supplied by AssistNow is used by a u-blox GNSS receiver to substantially reduce Time To First Fix, even under poor signal conditions. For more information about the AssistNow service, please see [this user guide on the u-blox website](https://www.u-blox.com/sites/default/files/products/documents/MultiGNSS-Assistance_UserGuide_%28UBX-13004360%29.pdf)

**Note** The AssistNow service enforces overuse restrictions. Since many imp agents share a single server (ie. a single source of HTTPS requests) it may be necessary to contact u-blox to ensure requests are not blocked.

**To include this library in your project, add** `#require "UBloxAssistNow.agent.lib.nut:1.0.0"` **at the top of your agent code.**

## Class Usage ##

### Request Callbacks ###

The methods [*requestOnline()*](#requestonlinereqparams-reqcallback) and [*requestOffline()*](#requestofflinereqparams-reqcallback) include a callback parameter. Any function passed into this parameter will be triggered when the response from AssistNow is received. The callback has two parameters: *error* and *response*. If no error was encountered, *error* will be `null`, otherwise it will be an error message string. The response from the server will be passed into *response*.

### Constructor: UBloxAssistNow(*token*) ###

To use this service you must register with u-blox and receive an [authorization token](http://www.u-blox.com/services-form.html).

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *token* | String | Yes | The authorization token supplied by u-blox *(see link above)* |

## Class Methods ##

### requestOnline(*reqParams, reqCallback*) ###

If the device is online, use this method to get data from AssistNow to improve your device's Time To First Fix. The data provided includes time-aid information, Earth orientation parameters, and satellite almanacs, ephemerides and health information. Server-side data is updated every 30-60 minutes.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *reqParams* | Table | Yes | Table of request parameters. Can be an empty table *([see below](#online-request-parameters))* |
| *reqCallback* | Function | Yes | Function that will be triggered when the response from AssistNow is received *([see ‘Request Callbacks’ for details](#request-callbacks))* |

#### Online Request Parameters ####

| Key&nbsp;Name | Type | Possible&nbsp;Values | Default | Description |
| --- | --- | --- | --- | --- |
| *datatype* | Array of strings | `"eph"`, `"alm"`, `"aux"`, `"pos"` | None | The data types required. Time data is always returned for each request, even if this parameter is not supplied |
| *format* | String | `"mga"`, `"aid"` | `"mga"` | Specifies the format of the data returned:<br />`"mga"` = UBXMGA-* (M8 module and up)<br />`"aid"` = UBX-AID-* (U7 module or earlier) |
| *gnss* | Array of strings | `"gps"`, `"qzss"`, `"glo"`, `"bds"`, `"gal"` | `"gps"` | GNSS for which data should be returned |
| *lat* | String or float | -90 to 90 | None | Approximate user latitude in WGS 84 in units of degrees and fractional degrees |
| *lon* | String or float | -180 to 180 | None | Approximate user longitude in WGS 84 in units of degrees and fractional degrees |
| *alt* | String or float | -1000 to 50000 | 0 | Approximate user altitude above WGS 84 ellipsoid in units of meters |
| *pacc* | String or float | 0 to 6000000 | None | Approximate accuracy of the submitted position in meters |
| *tacc* | String or float | 0 to 3600 | None | The timing accuracy in seconds |
| *latency* | String or float | 0 to 3600 | None | Typical latency in seconds between the time the server receives the request and the time the assistance data arrives at the GNSS receiver |
| *filteronpos* | None | None | None | If this key is present in table, the ephemeris data returned will only contain information for the satellites which are likely to be visible from the approximate position provided (see the *lat*, *lon*, *alt* and *pacc* parameters). If an approximate position is not provided, no filtering will be performed |
| *filteronsv* | Array of strings | &nbsp; | None | An array of u-blox gnssId:svId pairs. The ephemeris data returned will only contain data for the listed satellites |

**Note** To maintain accuracy, we recommended you use strings rather than float values for the *lat*, *lon*, *alt*, *pacc*, *tacc* and *latency* parameters. Floats will be converted to strings using `format("%f", floatVal)`.

#### Returns ####

Nothing.

### requestOffline(*reqParams, reqCallback*) ###

If the device is likely to have connection issues, use this when the device is online to download data from the AssistNow Offline Service, specifying the time period (one to five weeks) and the type(s) of GNSS to use so your device can estimate the positions of the satellites when no live data is available. The data returned will need to be stored in the device’s Flash and transferred to the u-blox receiver for use. Using these estimates does not provide as accurate a position fix as if current ephemeris data is used, but it allows much faster Time To First Fix (TTFF) in nearly all cases.

The data obtained from AssistNow is organized by date, normally a day at a time. Consequently the more weeks for which coverage is requested, the larger the amount of data your application will need to manage and store. Similarly, each different GNSS requires its own data. In extreme cases, the service may provide several hundred kilobytes of data. This volume of data can be reduced by requesting a lower resolution, but this has a small negative impact on both position accuracy and TTFF. Server-side data is updated daily or twice daily.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *reqParams* | Table | Yes | Table of request parameters. Must contain a *gnss*, all other values are optional *([see below](#offline-request-parameters))* |
| *reqCallback* | Function | Yes | Function that will be triggered when the response from AssistNow is received *([see ‘Request Callbacks’ for details](#request-callbacks))* |

#### Offline Request Parameters ####

| Key&nbsp;Name | Type | Possible&nbsp;Values | Default | Description |
| --- | --- | --- | --- | --- |
| *gnss* | Array of strings | `"gps"`, `"glo"` | None | The GNSS for which data should be returned. The table **must** include this key |
| *format* | String | `"mga"`, `"aid"` | `"mga"` | Specifies the format of the data returned:<br />`"mga"` = UBXMGA-* (M8 module and up)<br />`"aid"` = UBX-AID-* (U7 module or earlier) |
| *period* | Integer | 1, 2, 3, 4, 5 | 4 | The number of weeks into the future for which data can be downloaded. Data can be requested up to five weeks in advance |
| *resolution* | Integer | 1, 2, 3 | 1 | The resolution of the data:<br />1 = Every day<br />2 = Every other day<br />3 = Every third day |
| *days* | Integer | 1, 2, 3, 5, 7, 10, 14 | 14 | The GNSS for which data should be returned. Supported on U7 module or earlier |
| *almanac* | Array of strings | `"gps"`, `"glo"`, `"bds"`, `"gal"`, `"qzss"` | None | Added before MGA data is uploaded. Supported on MGA only |

#### Returns ####

Nothing.

### getOfflineMsgByDate(*offlineResp[, dateFormatter][, logErrors]*) ###

This method takes the response from [*requestOffline()*](#requestofflinereqparams-reqcallback) and returns a table of UBX-MGA-ANO assist messages organized by date.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *offlineResp* | HTTP response | Yes | The response parameter returned from [*requestOffline()*](#requestofflinereqparams-reqcallback) |
| *dateFormatter* | Function | No | A function that takes the year, month and day bytes from a UBX-MGA-ANO message payload and formats them into a date string |
| *logErrors* | Bool | No | Whether errors encountered when parsing offline response data should be logged. Default: `false` |

#### Returns ####

Table &mdash; keys are date strings created via the *dateFormatter*, and values are a concatenated string of all messages for that date. If the response doesn’t have a 200 status code, or if no UBX-MGA-ANO messages are found, the table will be empty.

### formatDateString(*year, month, day*) ###

This method takes the year, month and day bytes from the AssistNow payload and returns a date string formatted `YYYYMMDD`. This is the formatter used by [*getOfflineMsgByDate()*](#getofflinemsgbydateofflineresp-dateformatter-logerrors) if one is not specified.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *year* | Integer | Yes | Year from the AssistNow message |
| *month* | Integer | Yes | Month from the AssistNow message |
| *day* | Integer | Yes | Day from the AssistNow message |

#### Return Value ####

String &mdash; a date formatted as `YYYYMMDD`.

### setHeaders(*headers*) ###

By default there are no HTTP request headers set, and the imp API’s defaults will be used. Use this method to customize HTTP request headers if needed.

#### Parameters ####

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *headers* | Table | Yes | Table of HTTP headers |

#### Return Value ####

Nothing.

## License ##

These library is licensed under the [MIT License](../LICENSE).