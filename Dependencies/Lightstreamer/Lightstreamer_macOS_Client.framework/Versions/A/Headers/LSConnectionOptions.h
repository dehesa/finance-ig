//
//  LSConnectionOptions.h
//  Lightstreamer client for iOS UCA
//

#import <Foundation/Foundation.h>


/**
 @brief Used by LSLightstreamerClient to provide an extra connection properties bean.
 <br/> Bean object that contains the policy settings used to connect to a Lightstreamer Server.
 <br/> An instance of this class is attached to every LSLightstreamerClient as LSLightstreamerClient#connectionOptions <br/>
 */
@interface LSConnectionOptions : NSObject


/**
 @brief Maximum number of streaming connections that can be concurrently opened to the same Server (host and port).
 <br/> Since each LSLightstreamerClient instance may open a single streaming connection, the limit is applied between all the LSLightstreamerClient
 instances. See #maxConcurrentSessionsPerServerExceededPolicy for the policy to be applied when this limit is reached.
 <br/> Note: this is a class property.
 <br/> Default: 2 on iOS and tvOS; 3 on macOS.
 <br/> The change is effective immediately, but active connections that are in excess of this value won't be closed. The value is only checked during 
 the execution of the LSLightstreamerClient#connect method.
 <br/> The maximum value is 4 on iOS and tvOS, 6 on macOS. Trying to set a higher value will clip it to the maximum.
 <br/> Note: a change to this setting will NOT be notified through a call to LSClientDelegate#client:didChangeProperty:.
 */
@property (class, nonatomic, assign) NSUInteger maxConcurrentSessionsPerServer;

/**
 @brief Extra time the client is allowed to wait for a response to a request before dropping the connection and try with a different approach.
 <br/> It can either be a fixed value, in which case the same timeout is always used, or the string "auto" meaning that the library might
 change this timeout at will. In this case it is possible to check the current value with the the #currentConnectTimeout property.
 <br/> Streaming: The timeout is applied on any attempt to setup the streaming connection. If after the
 timeout no data has arrived on the stream connection, the client may automatically switch transport
 or may resort to a polling connection.
 <br/> Polling and pre-flight request: The timeout is applied to every connection. If after the timeout
 no data has arrived on the polling connection, the entire connection process restarts from scratch.
 <br/> Default: "auto"
 <br/> This value can be set and changed at any time.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "connectTimeout" on any
 LSClientDelegate listening to the related LSLightstreamerClient.
 @throws NSException if a negative or zero value is configured
 */
@property (nonatomic, assign, nonnull) NSString *connectTimeout;

/**
 @brief Extra time the client is allowed to wait for a response to a request before dropping the connection and try with a different approach.
 <br/> If #connectTimeout is set to "auto" this value might be later changed by the library, on the other hand if #connectTimeout is configured 
 to a fixed value this method will have no effect.
 <br/> Default: 4 seconds.
 <br/> This value can be set and changed at any time.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "currentConnectTimeout" on any
 LSClientDelegate listening to the related LSLightstreamerClient.
 @throws NSException if a negative or zero value is configured
 */
@property (nonatomic, assign) NSTimeInterval currentConnectTimeout;

/**
 @brief Length expressed in bytes to be used by the Server for the response body on a HTTP stream connection (a minimum length, however, is ensured by the server).
 <br/> After the content length exhaustion, the connection will be closed and a new bind connection will be automatically reopened. If it is 0, the length 
 is decided by the Server.
 <br/> NOTE that this setting only applies to the "HTTP-STREAMING" case (i.e. not to WebSockets).
 <br/> Default: A length decided by the library, to ensure the best performance. It can be of a few MB or much higher, depending on the environment.
 <br/> The content length should be set on the LSLightstreamerClient#connectionOptions object before calling the LSLightstreamerClient#connect method. However, 
 the value can be changed at any time: the supplied value will be used for the next HTTP bind request.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "contentLength" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 @throws NSException if a zero value is configured
 */
@property (nonatomic, assign) uint64_t contentLength;

/**
 @brief Maximum time the client will wait before opening a new session in case the previous one is unexpectedly closed while correctly working.
 <br/> The actual delay is a randomized value between 0 and this value. This randomization might help avoid a load spike on the cluster due to simultaneous r
 econnections, should one of the active servers be stopped. Note that this delay is only applied before the first reconnection: should such reconnection 
 fail the setting of #retryDelay is applied.
 <br/> Default: 0.1 seconds
 <br/> This value can be set and changed at any time.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "firstRetryMaxDelay" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 @throws NSException if a negative or zero value is configured
 */
@property (nonatomic, assign) NSTimeInterval firstRetryMaxDelay;

/**
 @brief Value of the forced transport (if any), that can be used to disable/enable the Stream-Sense algorithm and to force the client to use a fixed transport 
 or a fixed combination of a transport and a connection type.
 <br/> When a combination is specified the Stream-Sense algorithm is completely disabled.
 <br/> The method can be used to switch between streaming and polling connection types and between HTTP and WebSocket transports.
 <br/> In some cases, the requested status may not be reached, because of connection or environment problems. In that case the client will continuously attempt 
 to reach the configured status(es).
 <br/> Note that if the Stream-Sense algorithm is disabled, the client may still enter the "CONNECTED:STREAM-SENSING" status; however, in that case, if it 
 eventually finds out that streaming is not possible, no recovery will be tried.
 <br/> Default: nil (full Stream-Sense enabled).
 <br/> This method can be called at any time. If called while the client is connecting or connected it will instruct to switch connection type to match the
 given configuration.
 <br/> NOTE: In the current version WebSockets are not enabled, hence the default is actually "HTTP". Setting this value to "WS", "WS-STREAMING" or "WS-POLLING" 
 will prevent the library from working.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "forcedTransport" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 @throws NSException if the given value is not in the list of the admitted ones.
 */
@property (nonatomic, copy, nullable) NSString *forcedTransport;

/**
 @brief Enables/disables the setting of extra HTTP headers to all the request performed to the Lightstreamer server by the client.
 <br/> Note that the Content-Type header is reserved by the client library itself, while other headers might be refused by the environment and others might 
 cause the connection to the server to fail. The use of custom headers might also cause the client to send an OPTIONS request to the server before opening the 
 actual connection.
 <br/> Default: nil (meaning no extra headers are sent).
 <br/> This method can be called at any time: each request will carry headers accordingly to the most recent setting. Note that if extra headers are specified 
 while a WebSocket is open, the requests will continue to be sent through the WebSocket and thus this setting will be ignored until a new session starts.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "HTTPExtraHeaders" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 */
@property (nonatomic, copy, nullable) NSDictionary *HTTPExtraHeaders;

/**
 @brief Maximum time the Server is allowed to wait for any data to be sent in response to a polling request, if none has accumulated at request time.
 <br/> Setting this time to a nonzero value and the polling interval to zero leads to an "asynchronous polling" behaviour, which, on low data rates, is very
 similar to the streaming case. Setting this time to zero and the polling interval to a nonzero value, on the other hand, leads to a classical 
 "synchronous polling".
 <br/> Note that the Server may, in some cases, delay the answer for more than the supplied time, to protect itself against a high polling rate or because 
 of bandwidth restrictions. Also, the Server may impose an upper limit on the wait time, in order to be able to check for client-side connection drops.
 <br/> Default: 19 seconds.
 <br/> The idle timeout should be set on the LSLightstreamerClient#connectionOptions object before calling the LSLightstreamerClient#connect method. However, 
 the value can be changed at any time: the supplied value will be used for the next polling request (this only applies to the "*-POLLING" cases).
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "idleTimeout" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 @throws NSException if a negative value is configured
 */
@property (nonatomic, assign) NSTimeInterval idleTimeout;

/**
 @brief Interval between two keepalive packets sent by Lightstreamer Server on a stream connection when no actual data is being transmitted.
 <br/> The Server may, however, impose a lower limit on the keepalive interval, in order to protect itself. Also, the Server may impose an upper limit on the 
 keepalive interval, in order to be able to check for client-side connection drops. If no value is supplied, the Server will send keepalive packets based on 
 its own configuration. 
 <br/> The keepalive interval should be set on the LSLightstreamerClient#connectionOptions object before calling the LSLightstreamerClient#connect method. 
 However, the value can be changed at any time: the supplied value will be used for the next bind request (this only applies to the "*-STREAMING" cases).
 <br/> Note that, if the value has just been set and a connection to Lightstreamer Server has not been established yet, the returned value is the time that is being
 requested to the Server. After a connection, the value may be changed to the one imposed by the Server.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "keepaliveInterval" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 @throws NSException if a negative value is configured
 */
@property (nonatomic, assign) NSTimeInterval keepaliveInterval;

/**
 @brief Maximum bandwidth expressed in kilobits/s that can be consumed for the data coming from Lightstreamer Server.
 <br/> A limit on bandwidth may already be posed by the Metadata Adapter, but the client can furtherly restrict this limit. The limit applies to the bytes 
 received in each streaming or polling connection.
 <br/> The request is ignored by the Server if it runs in Allegro edition (i.e. "unlimited" is assumed).
 <br/> The request is ignored by the Server if it runs in Moderato edition (i.e. "unlimited" is assumed).
 <br/> Default: "unlimited".
 <br/> The bandwidth limit can be set and changed at any time. If a connection is currently active, the bandwidth limit for the connection is changed on the fly.
 <br/> Note that, if the value has just been set and a connection to Lightstreamer Server has not been established yet, the returned value is the bandwidth limit that is
 being requested to the Server. After a connection, the value may be changed to the one imposed by the Server.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "maxBandwidth" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 <br/> NOTE: In the current version, the actual value used by the Server is not notified when this method is called at runtime.
 @throws NSException if a negative, zero, or a not-number value (excluding special values) is passed.
 */
@property (nonatomic, copy, nonnull) NSString *maxBandwidth;

/**
 @brief Polling interval used for polling connections.
 <br/> The client switches from the default streaming mode to polling mode when the client network infrastructure does not allow streaming. Also, 
 polling mode can be forced by setting #forcedTransport to "WS-POLLING" or "HTTP-POLLING".
 <br/> The polling interval affects the rate at which polling requests are issued. It is the time between the start of a polling request and the start of 
 the next request. However, if the polling interval expires before the first polling request has returned, then the second polling request is delayed. This 
 may happen, for instance, when the Server delays the answer because of the idle timeout setting. In any case, the polling interval allows for setting an upper 
 limit on the polling frequency.
 <br/> The Server does not impose a lower limit on the client polling interval. However, in some cases, it may protect itself against a high polling rate by 
 delaying its answer. Network limitations and configured bandwidth limits may also lower the polling rate, despite of the client polling interval.
 <br/> The Server may, however, impose an upper limit on the polling interval, in order to be able to promptly detect terminated polling request sequences and
 discard related session information.
 <br/> Default: 0 (pure "asynchronous polling" is configured).
 <br/> The polling interval should be set on the LSLightstreamerClient#connectionOptions object before calling the LSLightstreamerClient#connect method. However, 
 the value can be changed at any time: the supplied value will be used for the next bind request (this only applies to the "*-POLLING" cases).
 <br/> Note that, if the value has just been set and a polling request to Lightstreamer Server has not been performed yet, the returned value is the polling interval 
 that is being requested to the Server. After each polling request, the value may be changed to the one imposed by the Server.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "pollingInterval" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 @throws NSException if a negative value is configured
 */
@property (nonatomic, assign) NSTimeInterval pollingInterval;

/**
 @brief Time the client, after entering "STALLED" status, can wait for a keepalive packet or any data on a stream connection, before disconnecting and trying to 
 reconnect to the Server.
 <br/> Default: 3 seconds.
 <br/> This value can be set and changed at any time.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "reconnectTimeout" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 @throws NSException if a negative or zero value is configured
 */
@property (nonatomic, assign) NSTimeInterval reconnectTimeout;

/**
 @brief Time the client can wait before opening a new session in case the previous one failed to open or was closed before it became stable.
 <br/> Note that the delay is calculated from the moment the effort to create a new connection is made, not from the moment the failure is detected or the 
 connection timeout expired.
 <br/> Default: 5 seconds.
 <br/> This value can be set and changed at any time.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "retryDelay" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 @throws NSException if a negative or zero value is configured
 */
@property (nonatomic, assign) NSTimeInterval retryDelay;

/**
 @brief Reverse-heartbeat interval on the control connection.
 <br/> If the given value equals 0 then the reverse-heartbeat mechanism will be disabled; otherwise if the given value 
 is greater than 0 the mechanism will be enabled with the specified interval.
 <br/> When the mechanism is active the client will send a set of empty control requests to the server, so that there is 
 at most the specified interval between a control request and the following one. The mechanism is not for general use 
 and should only be activated if there is a need to keep the control HTTP connection open even when idle, to avoid 
 connection reestablishment overhead. However it is not guaranteed that the connection will be kept open, as the underlying 
 TCP implementation may open a new socket each time a HTTP request needs to be sent.
 <br/> NOTE: The mechanism is automatically disabled during polling sessions and/or if the current session transport is a WebSocket.
 <br/> Default: 0 (meaning that the mechanism is disabled).
 <br/> This method can be called at any time enabling/disabling the reverse-heartbeat mechanism on the fly (if applicable).
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument
 "reverseHeartbeatInterval" on any LSClientDelegate listening to the related LSLightstreamerClient.
 @throws NSException if a negative value is configured
 */
@property (nonatomic, assign) NSTimeInterval reverseHeartbeatInterval;

/**
 @brief Extra time the client can wait when an expected keepalive packet has not been received on a stream connection (and 
 no actual data has arrived), before entering the "STALLED" status.
 <br/> Default: 2 seconds.
 <br/> This value can be set and changed at any time.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument
 "stalledTimeout" on any LSClientDelegate listening to the related LSLightstreamerClient.
 @throws NSException if a negative or zero value is configured
 */
@property (nonatomic, assign) NSTimeInterval stalledTimeout;

/**
 @brief Enables/disables the "early-open" of the WebSocket connection to the address specified in LSConnectionDetails#serverAddress.
 <br/> When enabled a WebSocket is open to the address specified through LSConnectionDetails#serverAddress before a potential server instance address is 
 received during session creation. In this case if a server instance address is received, the previously open WebSocket is closed and a new one is open 
 to the received server instance address.
 <br/> If disabled, the session creation is completed to verify if such a server instance address is configured in the server before opening the WebSocket.
 <br/> For these reasons this setting should be set to NO if the server specifies a &lt;control_link_address&gt; in its configuration; viceversa it
 should be set to YES if such element is not set on the target server(s) configuration.
 <br/> Default: YES.
 <br/> This method can be called at any time. If called while the client already owns a session it will be applied the next time a session is requested to a server.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "earlyWSOpenEnabled" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 <br/> NOTE: This method is only predisposed for forthcoming extensions. In the current version WebSockets are not enabled, this setting has no effect (see #forcedTransport).
 <br/> Server Clustering is not supported when using Lightstreamer in Moderato edition.
 */
@property (nonatomic, assign, getter=isEarlyWSOpenEnabled) BOOL earlyWSOpenEnabled;

/**
 @brief Policy to be applied during the LSLightstreamerClient#connect execution if there are already LSConnectionOtions#maxConcurrentSessionsPerServer streaming sessions
 open to the same Server (host and port).
 <br/> Possible values are: <ul>
 <li> "USE-POLLING": The client switches to a forced HTTP-POLLING mode, with idle timeout set to 0 seconds and polling interval set to 1 second (change to the polling
 timeout is applied only if it is currently lower). Switching to polling mode tries to avoid the exhaustion of the system-wide connection pool (typically sized 4 on
 iOS and 6 on macOS) by leaving the connection reusable by this and other clients.
 <br/>The changes to the connection options are notified through calls to LSClientDelegate#client:didChangeProperty: on any LSClientDelegate listening to 
 the related LSLightstreamerClient.
 <li> "BLOCK": The client aborts the LSLightstreamerClient#connect call by throwing an exception.
 <li> "NONE": No action is taken. If the system-wide connection pool is exhausted, the LSLightstreamerClient#connect call may timeout unexpectedly.
 </ul>
 <br/> Default: "NONE"
 <br/> Note: a change to this setting will NOT be notified through a call to LSClientDelegate#client:didChangeProperty:.
 @throws NSException if an invalid or nil value is configured
 */
@property (nonatomic, copy, nonnull) NSString *maxConcurrentSessionsPerServerExceededPolicy;

/**
 @brief Enables/disables a restriction on the forwarding of the extra http headers specified through #HTTPExtraHeaders.
 <br/> If YES, said headers will only be sent during the session creation process (and thus will still be available to the metadata adapter notifyUser method) 
 but will not be sent on following requests. On the contrary, when set to true, the specified extra headers will be sent to the server on every request.
 <br/> Default: NO.
 <br/> This method can be called at any time enabling/disabling the sending of headers on future requests.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "HTTPExtraHeadersOnSessionCreationOnly" on
 any LSClientDelegate listening to the related LSLightstreamerClient.
 */
@property (nonatomic, assign, getter=isHttpExtraHeadersOnSessionCreationOnly) BOOL HTTPExtraHeadersOnSessionCreationOnly;

/**
 @brief Disable/enable the automatic handling of server instance address that may be returned by the Lightstreamer server during session creation.
 <br/> In fact, when a Server cluster is in place, the Server address specified through LSConnectionDetails#serverAddress can identify various Server instances; 
 in order to ensure that all requests related to a session are issued to the same Server instance, the Server can answer to the session opening request by 
 providing an address which uniquely identifies its own instance.
 <br/> Setting this value to YES permits to ignore that address and to always connect through the address supplied in serverAddress. This may be needed in a 
 test environment, if the Server address specified is actually a local address to a specific Server instance in the cluster.
 <br/> Server Clustering is not supported when using Lightstreamer in Moderato edition.
 <br/> Default: NO.
 <br/> This method can be called at any time. If called while connected, it will be applied when the next session creation request is issued.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "serverInstanceAddressIgnored" on any
 LSClientDelegate listening to the related LSLightstreamerClient.
 */
@property (nonatomic, assign, getter=isServerInstanceAddressIgnored) BOOL serverInstanceAddressIgnored;

/**
 @brief Turns on or off the slowing algorithm.
 <br/> This heuristic algorithm tries to detect when the client CPU is not able to keep the pace of the events sent by the Server on a streaming connection. 
 In that case, an automatic transition to polling is performed.
 <br/> In polling, the client handles all the data before issuing the next poll, hence a slow client would just delay the polls, while the Server accumulates 
 and merges the events and ensures that no obsolete data is sent.
 <br/> Only in very slow clients, the next polling request may be so much delayed that the Server disposes the session first, because of its protection timeouts. 
 In this case, a request for a fresh session will be reissued by the client and this may happen in cycle.
 <br/> Default: YES.
 <br/> The algorithm should be enabled/disabled on the LSLightstreamerClient#connectionOptions object before calling the LSLightstreamerClient#connect method. 
 However, the value can be changed at any time: the supplied value will be used for the next connection attempt.
 <br/> NOTE: This method is only predisposed for forthcoming extensions. In the current version this setting has no effect.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#client:didChangeProperty: with argument "slowingEnabled" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 */
@property (nonatomic, assign, getter=isSlowingEnabled) BOOL slowingEnabled;


@end
