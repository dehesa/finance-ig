//
//  LSConnectionDetails.h
//  Lightstreamer client for iOS UCA
//

#import <Foundation/Foundation.h>


/**
 @brief Used by LSLightstreamerClient to provide a basic connection properties bean.
 <br/> Bean object that contains the configuration settings needed to connect to a Lightstreamer Server.
 <br/> An instance of this class is attached to every LSLightstreamerClient as LSLightstreamerClient#connectionDetails <br/>
 */
@interface LSConnectionDetails : NSObject


/**
 @brief Name of the Adapter Set (which defines the Metadata Adapter and one or several Data Adapters) mounted on Lightstreamer Server that supply all the items 
 used in this application.
 <br/> An Adapter Set defines the Metadata Adapter and one or several Data Adapters. It is configured on the server side through an "adapters.xml" file; 
 the name is configured through the "id" attribute in the <adapters_conf> element. The default Adapter Set, configured as "DEFAULT" on the Server.
 The Adapter Set name should be set on the LightstreamerClient#connectionDetails object before calling the LightstreamerClient#connect method. However, the value 
 can be changed at any time: the supplied value will be used for the next time a new session is requested to the server.
 <br/> This setting can also be specified in the LSLightstreamerClient constructor. A nil value is equivalent to the "DEFAULT" name.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#propertyDidChange with argument "adapterSet" on any LSClientDelegate 
 listening to the related LSLightstreamerClient.
 */
@property (nonatomic, copy, nullable) NSString *adapterSet;


/**
 @brief Configured address of Lightstreamer Server.
 <br/> Note that the addresses specified must always have the http: or https: scheme. In case WebSockets are used, the specified scheme is internally converted to 
 match the related WebSocket protocol (i.e. http becomes ws while https becomes wss). WSS/HTTPS connections are not supported by the Server if it runs in Allegro 
 edition. WSS/HTTPS connections are not supported by the Server if it runs in Moderato edition. If no server address is supplied the client will be unable to connect.
 This method can be called at any time. If called while connected, it will be applied when the next session creation request is issued. This setting can also be 
 specified in the LightstreamerClient constructor. A nil value can also be used, to restore the default value. An IPv4 or IPv6 can also be used in place of a
 hostname. Some examples of valid values include:<ul>
 <li> http://push.mycompany.com
 <li> http://push.mycompany.com:8080
 <li> http://79.125.7.252
 <li> http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]
 <li> http://[2001:0db8:85a3::8a2e:0370:7334]:8080
 </ul>
 <br/> A change to this setting will be notified through a call to LSClientDelegate#propertyDidChange with argument "serverAddress" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 @throws NSException if the given address is not valid.
 */
@property (nonatomic, copy, nullable) NSString *serverAddress;

/**
 @brief Server address to be used to issue all requests related to the current session.
 <br/> In fact, when a Server cluster is in place, the Server address specified through #serverAddress can identify various Server instances; in order to ensure
 that all requests related to a session are issued to the same Server instance, the Server can answer to the session opening request by providing an address which 
 uniquely identifies its own instance. When this is the case, this address is returned by the method; otherwise, nil is returned.
 <br/> Note that the addresses will always have the http: or https: scheme. In case WebSockets are used, the specified scheme is internally converted to match the 
 related WebSocket protocol (i.e. http becomes ws while https becomes wss). 
 <br/> Server Clustering is not supported when using Lightstreamer in Moderato edition.
 <br/> The method gives a meaningful answer only when a session is currently active.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#propertyDidChange with argument "serverInstanceAddress" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 */
@property (nonatomic, readonly, nullable) NSString *serverInstanceAddress;

/**
 @brief Instance name of the Server which is serving the current session.
 <br/> To be more precise, each answering port configured on a Server instance (through a <http_server> or <https_server> element in the Server configuration file) can
 be given a different name; the name related to the port to which the session opening request has been issued is returned. Note that in case of polling or in case 
 rebind requests are needed, subsequent requests related to the same session may be issued to a port different than the one used for the first request; 
 the names configured for those ports would not be reported. This, however, can only happen when a Server cluster is in place and particular configurations for 
 the load balancer are used.
 <br/> Server Clustering is not supported when using Lightstreamer in Moderato edition.
 <br/> The method gives a meaningful answer only when a session is currently active.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#propertyDidChange with argument "serverSocketName" on any LSClientDelegate
 listening to the related LSLightstreamerClient.
 */
@property (nonatomic, readonly, nullable) NSString *serverSocketName;

/**
 @brief ID associated by the server to this client session.
 <br/> The method gives a meaningful answer only when a session is currently active.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#propertyDidChange with argument "sessionId" on any LSClientDelegate 
 listening to the related LSLightstreamerClient.
 */
@property (nonatomic, readonly, nullable) NSString *sessionId;

/**
 @brief Username to be used for the authentication on Lightstreamer Server when initiating the push session.
 <br/> The Metadata Adapter is responsible for checking the credentials (username and password). If no username is supplied, no user information will be sent at session
 initiation. The Metadata Adapter, however, may still allow the session. The username should be set on the LSLightstreamerClient#connectionDetails object before
 calling the LSLightstreamerClient#connect method. However, the value can be changed at any time: the supplied value will be used for the next time a new session 
 is requested to the server.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#propertyDidChange with argument "user" on any LSClientDelegate 
 listening to the related LSLightstreamerClient.
 */
@property (nonatomic, copy, nullable) NSString *user;

/**
 @brief Setter method that sets the password to be used for the authentication on Lightstreamer Server when initiating the push session.
 <br/> The Metadata Adapter is responsible for checking the credentials (username and password).
 If no password is supplied, no password information will be sent at session initiation. The Metadata Adapter, however, may still allow the session.
 The username should be set on the LightstreamerClient#connectionDetails object before calling the LightstreamerClient#connect method. However, the value can be 
 changed at any time: the supplied value will be used for the next time a new session is requested to the server.
 <br/> NOTE: The password string will be stored in the current instance. That is necessary in order to allow automatic reconnection/reauthentication for fail-over. 
 For maximum security, avoid using an actual private password to authenticate on Lightstreamer Server; rather use a session-id originated by your web/application 
 server, that can be checked by your Metadata Adapter.
 <br/> A change to this setting will be notified through a call to LSClientDelegate#propertyDidChange with argument "password" on any LSClientDelegate 
 listening to the related LSLightstreamerClient.
 @param password The password to be used for the authentication on Lightstreamer Server. The password can be nil.
 */
- (void) setPassword:(nullable NSString *)password;


@end
