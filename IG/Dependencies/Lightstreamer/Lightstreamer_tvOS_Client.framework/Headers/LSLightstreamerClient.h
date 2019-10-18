//
//  LSLightstreamerClient.h
//  Lightstreamer client for iOS UCA
//

#import <Foundation/Foundation.h>


@class LSConnectionDetails;
@class LSConnectionOptions;
@class LSSubscription;

@protocol LSClientDelegate;
@protocol LSClientMessageDelegate;
@protocol LSLoggerProvider;


/**
 @brief Façade class for the management of the communication to Lightstreamer Server.
 <br/> Used to provide configuration settings, event handlers, operations for the control of the connection lifecycle, subscription handling and to send messages.
 */
@interface LSLightstreamerClient : NSObject

/**
 @brief A constant string representing the name of the library.
 */
@property (class, nonatomic, readonly, nonnull) NSString *LIB_NAME;

/**
 @brief A constant string representing the version of the library.
 */
@property (class, nonatomic, readonly, nonnull) NSString *LIB_VERSION;

/**
 @brief Reduces the use of exceptions for error reporting.
 <br/> When set to YES, the following method calls will return nil, instead of throwing an exception, when called with invalid parameters:<ul>
 <li> LSItemUpdate#valueWithFieldPos:</li>
 <li> LSItemUpdate#valueWithFieldName:</li>
 <li> LSItemUpdate#isValueChangedWithFieldPos:</li>
 <li> LSItemUpdate#isValueChangedWithFieldName:</li>
 <li> LSSubscription#commandValueWithItemPos:key:fieldPos:</li>
 <li> LSSubscription#commandValueWithItemPos:key:fieldName:</li>
 <li> LSSubscription#commandValueWithItemName:key:fieldPos:</li>
 <li> LSSubscription#commandValueWithItemName:key:fieldName:</li>
 <li> LSSubscription#valueWithItemPos:fieldPos:</li>
 <li> LSSubscription#valueWithItemPos:fieldName:</li>
 <li> LSSubscription#valueWithItemName:fieldPos:</li>
 <li> LSSubscription#valueWithItemName:fieldName:</li>
 </ul>
 <br/> Default: NO
 <br/> This value may be changed at any time.
 */
@property (class, nonatomic, assign) BOOL limitExceptionsUse;

/**
 @brief Creates an object to be configured to connect to a Lightstreamer server and to handle all the communications with it.
 <br/> Each LSLightstreamerClient is the entry point to connect to a Lightstreamer server, subscribe to as many items as needed and to send messages.
 @param serverAddress the address of the Lightstreamer Server to which this LightstreamerClient will connect to. 
 It is possible to specify it later by using nil here. See LSConnectionDetails#serverAddress for details.
 @param adapterSet the name of the Adapter Set mounted on Lightstreamer Server to be used to handle all requests in the Session associated 
 with this LightstreamerClient. It is possible not to specify it at all or to specify it later by using nil here. See LSConnectionDetails#adapterSet for details.
 @throws NSException if a not valid address is passed. See LSConnectionDetails#serverAddress for details.
 */
- (nonnull instancetype) initWithServerAddress:(nullable NSString *)serverAddress adapterSet:(nullable NSString *)adapterSet;

/**
 @brief Bean object that contains options and policies for the connection to the server.
 <br/> This instance is set up by the LSLightstreamerClient object at its own creation.
 <br/> Properties of this bean can be overwritten by values received from a Lightstreamer Server.
 */
@property (nonatomic, readonly, nonnull) LSConnectionOptions *connectionOptions;

/**
 @brief Bean object that contains the details needed to open a connection to a Lightstreamer Server.
 <br/> This instance is set up by the LightstreamerClient object at its own creation.
 <br/> Properties of this bean can be overwritten by values received from a Lightstreamer Server.
 */
@property (nonatomic, readonly, nonnull) LSConnectionDetails *connectionDetails;

/**
 @brief Adds a delegate that will receive events from the LSLightstreamerClient instance.
 <br/> The same delegate can be added to several different LSLightstreamerClient instances.
 A delegate can be added at any time. A call to add a delegate already present will be ignored.
 @param delegate An object that will receive the events as documented in the LSClientDelegate interface.
 <br/> Note: delegates are stored with weak references: make sure you keep a strong reference to your delegates or they may be released prematurely.
 */
- (void) addDelegate:(nonnull id <LSClientDelegate>)delegate;

/**
 @brief Operation method that requests to open a Session against the configured Lightstreamer Server.
 <br/> When #connect is called, unless a single transport was forced through LSConnectionOptions#forcedTransport, the so called "Stream-Sense" mechanism is started: 
 if the client does not receive any answer for some seconds from the streaming connection, then it will automatically open a polling connection.
 <br/> A polling connection may also be opened if the environment is not suitable for a streaming connection.
 <br/> Note that as "polling connection" we mean a loop of polling requests, each of which requires opening a synchronous (i.e. not streaming) connection to 
 Lightstreamer Server. Note that the request to connect is accomplished by the client in a separate thread; this means that an invocation of #status right
 after #connect might not reflect the change yet.
 <br/> When the request to connect is finally being executed, if the current status of the client is CONNECTING, CONNECTED:* or STALLED, then nothing will be done.
 @throws NSException if no server address was configured.
 @throws NSException if a LSConnectionOptions#maxConcurrentSessionsPerServerExceededPolicy of "BLOCKING" was specified an the current number of sessions
 open to the configured server address is equal to or greater than LSConnectionOptions#maxConcurrentSessionsPerServer.
 */
- (void) connect;

/**
 @brief Operation method that requests to close the Session opened against the configured Lightstreamer Server (if any).
 <br/> When #disconnect is called, the "Stream-Sense" mechanism is stopped.
 <br/> Note that active LSSubscription instances, associated with this LightstreamerClient instance, are preserved to be re-subscribed to on future Sessions.
 <br/> Note that the request to disconnect is accomplished by the client in a separate thread; this means that an invocation of #status right after #disconnect
 might not reflect the change yet.
 <br/> When the request to disconnect is finally being executed, if the status of the client is "DISCONNECTED", then nothing will be done.
 */
- (void) disconnect;

/**
 @brief List containing the LSClientDelegate instances that were added to this client.
 @return a list containing the delegates that were added to this client.
 */
@property (nonatomic, readonly, nonnull) NSArray *delegates;

/**
 @brief Current client status and transport (when applicable).
 @return The current client status. It can be one of the following values: <ul> 
 <li>"CONNECTING" the client is waiting for a Server's response in order to establish a connection;</li> 
 <li>"CONNECTED:STREAM-SENSING" the client has received a preliminary response from the server and is currently verifying if a streaming connection is possible;</li> 
 <li>"CONNECTED:WS-STREAMING" a streaming connection over WebSocket is active;</li> 
 <li>"CONNECTED:HTTP-STREAMING" a streaming connection over HTTP is active;</li> 
 <li>"CONNECTED:WS-POLLING" a polling connection over WebSocket is in progress;</li> 
 <li>"CONNECTED:HTTP-POLLING" a polling connection over HTTP is in progress;</li> 
 <li>"STALLED" the Server has not been sending data on an active streaming connection for longer than a configured time;</li> 
 <li>"DISCONNECTED" no connection is currently active;</li> 
 <li>"DISCONNECTED:WILL-RETRY" no connection is currently active but one will be open after a timeout.</li>
 </ul>
 */
@property (nonatomic, readonly, nonnull) NSString *status;

/**
 @brief List containing all the LSSubscription instances that are currently "active" on this LightstreamerClient.
 <br/> Internal second-level LSSubscription are not included.
 @return A list, containing all the LSSubscription currently "active" on this LSLightstreamerClient.
 <br/> The list can be empty.
 */
@property (nonatomic, readonly, nonnull) NSArray *subscriptions;

/**
 @brief Removes a delegate from the LSLightstreamerClient instance so that it will not receive events anymore. 
 <br/> A delegate can be removed at any time.
 @param delegate The delegate to be removed.
 */
- (void) removeDelegate:(nonnull id <LSClientDelegate>)delegate;

/**
 @brief A simplified version of the #sendMessage:withSequence:timeout:delegate:enqueWhileDisconnected:. 
 <br/> The internal implementation will call <code>sendMessage:message withSequence:nil timeout:0 delegate:nil enqueWhileDisconnected:NO</code>
 @param message a text message, whose interpretation is entirely demanded to the Metadata Adapter associated to the current connection.
 */
- (void) sendMessage:(nonnull NSString *)message;

/**
 @brief Operation method that sends a message to the Server.
 <br/> The message is interpreted and handled by the Metadata Adapter associated to the current Session. This operation supports in-order guaranteed message delivery
 with automatic batching. In other words, messages are guaranteed to arrive exactly once and respecting the original order, whatever is the underlying transport 
 (HTTP or WebSockets). Furthermore, high frequency messages are automatically batched, if necessary, to reduce network round trips.
 <br/> Upon subsequent calls to the method, the sequential management of the involved messages is guaranteed. The ordering is determined by the order in which 
 the calls to sendMessage are issued. However, any message that, for any reason, doesn't reach the Server can be discarded by the Server if this causes the 
 subsequent message to be kept waiting for longer than a configurable timeout. Note that, because of the asynchronous transport of the requests, if a zero or very 
 low timeout is set for a message, it is not guaranteed that the previous message can be processed, even if no communication issues occur.
 <br/> Sequence identifiers can also be associated with the messages. In this case, the sequential management is restricted to all subsets of messages with the 
 same sequence identifier associated.
 <br/> Notifications of the operation outcome can be received by supplying a suitable delegate. The supplied delegate is guaranteed to be eventually invoked;
 delegates associated with a sequence are guaranteed to be invoked sequentially.
 <br/> The "UNORDERED_MESSAGES" sequence name has a special meaning. For such a sequence, immediate processing is guaranteed, while strict ordering and even 
 sequentialization of the processing is not enforced. Likewise, strict ordering of the notifications is not enforced. However, messages that, for any reason, 
 should fail to reach the Server whereas subsequent messages had succeeded, might still be discarded after a server-side timeout.
 Since a message is handled by the Metadata Adapter associated to the current connection, a message can be sent only if a connection is currently active. 
 If the special enqueueWhileDisconnected flag is specified it is possible to call the method at any time and the client will take care of sending the message 
 as soon as a connection is available, otherwise, if the current status is "DISCONNECTED*", the message will be abandoned and the 
 LSClientMessageDelegate#messageDidAbort event will be fired.
 <br/> Note that, in any case, as soon as the status switches again to "DISCONNECTED*", any message still pending is aborted, including messages that were queued 
 with the enqueueWhileDisconnected flag set to true.
 <br/> Also note that forwarding of the message to the server is made in a separate thread, hence, if a message is sent while the connection is active, it could 
 be aborted because of a subsequent disconnection. In the same way a message sent while the connection is not active might be sent because of a subsequent connection.
 @param message a text message, whose interpretation is entirely demanded to the Metadata Adapter associated to the current connection.
 @param sequence an alphanumeric identifier, used to identify a subset of messages to be managed in sequence; underscore characters are also allowed. 
 If the "UNORDERED_MESSAGES" identifier is supplied, the message will be processed in the special way described above. The parameter is optional; 
 if set to nil, "UNORDERED_MESSAGES" is used as the sequence name.
 @param delayTimeout a timeout, expressed in seconds. If higher than the Server default timeout, the latter will be used instead.
 <br/> The parameter is optional; if 0 is supplied, the Server default timeout will be applied.
 <br/> This timeout is ignored for the special "UNORDERED_MESSAGES" sequence, for which a custom server-side timeout applies.
 @param delegate an object suitable for receiving notifications about the processing outcome. The parameter is optional; if not supplied,
 no notification will be available.
 <br/> Note: delegates are stored with weak references: make sure you keep a strong reference to your delegates or they may be released prematurely.
 @param enqueueWhileDisconnected if this flag is set to true, and the client is in a disconnected status when the provided message is handled, then the message
 is not aborted right away but is queued waiting for a new session. Note that the message can still be aborted later when a new session is established.
 */
- (void) sendMessage:(nonnull NSString *)message withSequence:(nullable NSString *)sequence timeout:(NSTimeInterval)delayTimeout delegate:(nullable id <LSClientMessageDelegate>)delegate enqueueWhileDisconnected:(BOOL)enqueueWhileDisconnected;

/**
 @brief Static method that permits to configure the logging system used by the library.
 <br/> The logging system must respect the LSLoggerProvider interface. A custom class can be used to wrap any third-party logging system.
 <br/> If no logging system is specified, all the generated log is discarded.
 <br/> The following categories are available to be consumed: <ul> 
 <li>lightstreamer.stream:
   <br/> logs socket activity on Lightstreamer Server connections;
   <br/> at INFO level, socket operations are logged;
   <br/> at DEBUG level, read/write data exchange is logged. </li> 
 <li>lightstreamer.protocol:
   <br/> logs requests to Lightstreamer Server and Server answers;
   <br/> at INFO level, requests are logged;
   <br/> at DEBUG level, request details and events from the Server are logged. </li>
 <li>lightstreamer.session:
   <br/> logs Server Session lifecycle events;
   <br/> at INFO level, lifecycle events are logged;
   <br/> at DEBUG level, lifecycle event details are logged. </li> 
 <li>lightstreamer.subscriptions:
   <br/> logs subscription requests received by the clients and the related updates;
   <br/> at WARN level, alert events from the Server are logged;
   <br/> at INFO level, subscriptions and unsubscriptions are logged;
   <br/> at DEBUG level, requests batching and update details are logged. </li> 
 <li>lightstreamer.actions:
   <br/> logs settings / API calls. </li> 
 </ul>
 @param provider A LSLoggerProvider instance that will be used to generate log messages by the library classes.
 */
+ (void) setLoggerProvider:(nonnull id <LSLoggerProvider>)provider;

/**
 @brief Operation method that adds a LSSubscription to the list of "active" subscriptions.
 <br/> The LSSubscription cannot already be in the "active" state.
 <br/> Active subscriptions are subscribed to through the server as soon as possible (i.e. as soon as there is a session available). Active LSSubscription
 are automatically persisted across different sessions as long as a related unsubscribe call is not issued.
 LSSubscriptions can be given to the LSLightstreamerClient at any time. Once done the LSSubscription immediately enters the "active" state.
 <br/> Once "active", a LSSubscription instance cannot be provided again to a LSLightstreamerClient unless it is first removed from the "active" state through 
 a call to #unsubscribe:.
 <br/> Also note that forwarding of the subscription to the server is made in a separate thread.
 <br/> A successful subscription to the server will be notified through a LSSubscriptionDelegate#subscriptionDidSubscribe event.
 @param subscription A LSSubscription object, carrying all the information needed to process its pushed values.
 */
- (void) subscribe:(nonnull LSSubscription *)subscription;

/**
 @brief Operation method that removes a LSSubscription that is currently in the "active" state.
 <br/> By bringing back a LSSubscription to the "inactive" state, the unsubscription from all its items is requested to Lightstreamer Server.
 LSSubscription can be unsubscribed from at any time. Once done the LSSubscription immediately exits the "active" state.
 <br/> Note that forwarding of the unsubscription to the server is made in a separate thread.
 <br/> The unsubscription will be notified through a LSSubscriptionDelegate#subscriptionDidUnsubscribe event.
 @param subscription An "active" LSSubscription object that was activated by this LSLightstreamerClient instance.
 */
- (void) unsubscribe:(nonnull LSSubscription *)subscription;


@end
