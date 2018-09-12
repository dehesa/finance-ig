//
//  LSClientDelegate.h
//  Lightstreamer client for iOS UCA
//

#import <Foundation/Foundation.h>


@class LSLightstreamerClient;


/**
 @brief Protocol to be implemented to receive LSLightstreamerClient events comprehending notifications of connection activity and errors.
 <br/> Events for these delegates are dispatched by a different thread than the one that generates them. This means that, upon reception of an event, 
 it is possible that the internal state of the client has changed. On the other hand, all the notifications for a single LSLightstreamerClient, including 
 notifications to LSClientDelegate s, LSSubscriptionDelegate s and LSClientMessageDelegate s will be dispatched by the same thread.
 */
@protocol LSClientDelegate <NSObject>


@optional
	
/**
 @brief Event handler that receives a notification when the LSClientDelegate instance is removed from a LSLightstreamerClient through 
 LSLightstreamerClient#removeDelegate:.
 <br/> This is the last event to be fired on the delegate.
 @param client the LSLightstreamerClient this instance was removed from.
 */
- (void) clientDidRemoveDelegate:(nonnull LSLightstreamerClient *)client;

/**
 @brief Event handler that receives a notification when the LSClientDelegate instance is added to a LSLightstreamerClient through 
 LSLightstreamerClient#addDelegate:.
 <br/> This is the first event to be fired on the delegate.
 @param client the LSLightstreamerClient this instance was added to.
 */
- (void) clientDidAddDelegate:(nonnull LSLightstreamerClient *)client;

/**
 @brief Event handler that is called when the Server notifies a refusal on the client attempt to open a new connection or the interruption of a streaming connection.
 <br/> In both cases, the #client:didChangeStatus: event handler has already been invoked with a "DISCONNECTED" status and no 
 recovery attempt has been performed. By setting a custom handler, however, it is possible to override this and perform custom recovery actions.
 @param client the LSLightstreamerClient instance.
 @param errorCode the error code. It can be one of the following: <ul>
 <li>1 - user/password check failed</li> 
 <li>2 - requested Adapter Set not available</li> 
 <li>7 - licensed maximum number of sessions reached (this can only happen with some licenses)</li> 
 <li>8 - configured maximum number of sessions reached</li> 
 <li>9 - configured maximum server load reached</li> 
 <li>10 - new sessions temporarily blocked</li> 
 <li>11 - streaming is not available because of Server license restrictions (this can only happen with special licenses) 
 <li>30-39 - the current connection or the whole session has been closed by external agents; the possible cause may be: <ul> 
   <li>The session was closed by the administrator, through JMX (32) or through a "destroy" request (31);</li> 
   <li>The Metadata Adapter imposes limits on the overall open sessions for the current user and has requested the closure of the current session upon opening 
   of a new session for the same user on a different browser window (35);</li> 
   <li>An unexpected error occurred on the Server while the session was in activity (33, 34);</li> 
   <li>An unknown or unexpected cause; any code different from the ones identified in the above cases could be issued. A detailed description for the specific 
   cause is currently not supplied (i.e. errorMessage is nil in this case).</li> 
   </ul>
 <li>61 - there was an error in the parsing of the server response thus the client cannot continue with the current session.</li> 
 <li><= 0 - the Metadata Adapter has refused the user connection; the code value is dependent on the specific Metadata Adapter implementation</li> 
 </ul>
 @param errorMessage the description of the error as sent by the Server.
 */
- (void) client:(nonnull LSLightstreamerClient *)client didReceiveServerError:(NSInteger)errorCode withMessage:(nullable NSString *)errorMessage;

/**
 @brief Event handler that receives a notification each time the LSLightstreamerClient status has changed.
 <br/> The status changes may be originated either by custom actions (e.g. by calling LSLightstreamerClient#disconnect) or by internal actions. The normal cases 
 are the following: <ul> 
 <li>After issuing LSLightstreamerClient#connect, if the current status is "DISCONNECTED*", the client will switch to "CONNECTING" first and to "CONNECTED:STREAM-SENSING" as soon as
 the pre-flight request receives its answer.
 <br/> As soon as the new session is established, it will switch to "CONNECTED:WS-STREAMING" if the environment permits WebSockets; otherwise it will switch 
 to "CONNECTED:HTTP-STREAMING" if the environment permits streaming or to "CONNECTED:HTTP-POLLING" as a last resort.
 <br/> On the other hand if the status is already "CONNECTED:*" a switch to "CONNECTING" is usually not needed.</li> 
 <li>After issuing LSLightstreamerClient#disconnect , the status will switch to "DISCONNECTED".</li> 
 <li>In case of a server connection refusal, the status may switch from "CONNECTING" directly to "DISCONNECTED". After that,
 the #client:didReceiveServerError:withMessage: event handler will be invoked.</li>
 </ul> Possible special cases are the following: <ul> 
 <li>In case of Server unavailability during streaming, the status may switch from "CONNECTED:*-STREAMING" to "STALLED" (see LSConnectionOptions#stalledTimeout).
 If the unavailability ceases, the status will switch back to ""CONNECTED:*-STREAMING""; otherwise, if the unavailability persists (see 
 LSConnectionOptions#reconnectTimeout), the status will switch to "CONNECTING" and eventually to "CONNECTED:*-STREAMING".</li> 
 <li>In case the connection or the whole session is forcibly closed by the Server, the status may switch from "CONNECTED:*-STREAMING" or "CONNECTED:*-POLLING" 
 directly to "DISCONNECTED". After that, the #client:didReceiveServerError:withMessage: event handler will be invoked.</li>
 <li>Depending on the setting in LSConnectionOptions#slowingEnabled, in case of slow update processing, the status may switch from "CONNECTED:WS-STREAMING" to
 "CONNECTED:WS-POLLING" or from "CONNECTED:HTTP-STREAMING" to "CONNECTED:HTTP-POLLING".</li> 
 <li>If the status is "CONNECTED:*POLLING" and any problem during an intermediate poll occurs, the status may switch to "CONNECTING" and eventually to 
 "CONNECTED:POLLING". The same holds for the "CONNECTED:STREAMING" case, when a rebind is needed.</li> 
 <li>In case a forced transport was set through LSConnectionOptions#forcedTransport, only the related final status or statuses are possible.</li> 
 <li>In case of connection problems the status may switch from any value to "DISCONNECTED:WILL-RETRY" (see LSConnectionOptions#retryDelay).</li> 
 </ul> By setting a custom handler it is possible to perform actions related to connection and disconnection occurrences. Note that LSLightstreamerClient#connect 
 and LSLightstreamerClient#disconnect, as any other method, can be issued directly from within a handler.
 @param client the LSLightstreamerClient instance.
 @param status the new status. It can be one of the following values: <ul>
 <li>"CONNECTING" the client has started a connection attempt and is waiting for a Server answer.</li> 
 <li>"CONNECTED:STREAM-SENSING" the client received a first response from the server and is now evaluating if a streaming connection is fully functional.</li> 
 <li>"CONNECTED:WS-STREAMING" a streaming connection over WebSocket has been established.</li> 
 <li>"CONNECTED:HTTP-STREAMING" a streaming connection over HTTP has been established.</li> 
 <li>"CONNECTED:WS-POLLING" a polling connection over WebSocket has been started. Note that, unlike polling over HTTP, in this case only one connection is actually 
 opened (see ConnectionOptions#setSlowingEnabled ).</li> 
 <li>"CONNECTED:HTTP-POLLING" a polling connection over HTTP has been started.</li> 
 <li>"STALLED" a streaming session has been silent for a while, the status will eventually return to its previous CONNECTED:*-STREAMING status or will switch 
 to "DISCONNECTED:WILL-RETRY".</li> 
 <li>"DISCONNECTED:WILL-RETRY" a connection or connection attempt has been closed; a new attempt will be performed after a timeout.</li> 
 <li>"DISCONNECTED" a connection or connection attempt has been closed. The client will not connect anymore until a new LSLightstreamerClient#connect 
 call is issued.</li> 
 </ul>
 */
- (void) client:(nonnull LSLightstreamerClient *)client didChangeStatus:(nonnull NSString *)status;

/**
 @brief Event handler that receives a notification each time the value of a property of LSLightstreamerClient#connectionDetails or
 LSLightstreamerClient#connectionOptions is changed.
 <br/> Properties of these objects can be modified by direct calls to them or by server sent events.
 @param client the LSLightstreamerClient instance.
 @param property the name of the changed property. 
 <br/> Possible values are: <ul> 
 <li>adapterSet</li> 
 <li>serverAddress</li> 
 <li>user</li> 
 <li>password</li> 
 <li>serverInstanceAddress</li> 
 <li>serverSocketName</li> 
 <li>sessionId</li> 
 <li>contentLength</li> 
 <li>idleMillis</li> 
 <li>keepaliveMillis</li> 
 <li>maxBandwidth</li> 
 <li>pollingMillis</li> 
 <li>reconnectTimeout</li> 
 <li>stalledTimeout</li> 
 <li>connectTimeout</li> 
 <li>currentConnectTimeout</li>
 <li>retryDelay</li>
 <li>firstRetryMaxDelay</li> 
 <li>slowingEnabled</li> 
 <li>forcedTransport</li> 
 <li>serverInstanceAddressIgnored</li> 
 <li>reverseHeartbeatMillis</li> 
 <li>earlyWSOpenEnabled</li> 
 <li>httpExtraHeaders</li> 
 <li>httpExtraHeadersOnSessionCreationOnly</li> 
 </ul>
 */
- (void) client:(nonnull LSLightstreamerClient *)client didChangeProperty:(nonnull NSString *)property;

/**
 @brief Event handler that receives a notificaiton each time the underlying connection is going to request authentication
 for a challenge in order to proceed.
 <br/> If the delegate implements this method, the connection will suspend until <code>challenge.sender</code>
 is called with one of the following methods: <ul>
 <li><code>useCredential:forAuthenticationChallenge:</code>,
 <li><code>continueWithoutCredentialForAuthenticationChallenge:</code>,
 <li><code>cancelAuthenticationChallenge:</code>,
 <li><code>performDefaultHandlingForAuthenticationChallenge:</code> or
 <li><code>rejectProtectionSpaceAndContinueWithChallenge:</code>.
 </ul>
 If not implemented, the default behavior will call <code>performDefaultHandlingForAuthenticationChallenge:</code>.
 <br/> Note that if more than one delegate is added to the same client, only the first one implementing this method will
 be notified of this event.
 <br/> Note also that this notification is called directly from the network thread. The method implementation should be
 fast and nonblocking. Any slow operations should have been performed in advance.
 @param client the LSLightstreamerClient instance.
 @param challenge The challenge that the client must authenticate in order to proceed with its request.
 */
- (void) client:(nonnull LSLightstreamerClient *)client willSendRequestForAuthenticationChallenge:(nonnull NSURLAuthenticationChallenge *)challenge;

@end

