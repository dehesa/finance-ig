//
//  LSClientMessageDelegate.h
//  Lightstreamer client for iOS UCA
//

#import <Foundation/Foundation.h>


@class LSLightstreamerClient;


/**
 @brief Protocol to be implemented to receive LSLightstreamerClient#sendMessage events reporting a message processing outcome.
 <br/> Events for these delegates are dispatched by a different thread than the one that generates them. All the notifications for a single LSLightstreamerClient,
 including notifications to LSClientDelegate s, LSSubscriptionDelegate s and LSClientMessageDelegate s will be dispatched by the same thread. Only one event 
 per message is fired on this delegate.
 */
@protocol LSClientMessageDelegate <NSObject>


@optional

/**
 @brief Event handler that is called by Lightstreamer when any notifications of the processing outcome of the related message haven't been received yet and 
 can no longer be received.
 <br/> Typically, this happens after the session has been closed. In this case, the client has no way of knowing the processing outcome and any outcome is possible.
 @param client the LSLightstreamerClient instance.
 @param originalMessage the message to which this notification is related.
 @param sentOnNetwork YES if the message was sent on the network, false otherwise. Even if the flag is YES, it is not possible to infer whether the message 
 actually reached the Lightstreamer Server or not.
 */
- (void) client:(nonnull LSLightstreamerClient *)client didAbortMessage:(nonnull NSString *)originalMessage sentOnNetwork:(BOOL)sentOnNetwork;

/**
 @brief Event handler that is called by Lightstreamer when the related message has been processed by the Server but the expected processing outcome could 
 not be achieved for any reason.
 @param client the LSLightstreamerClient instance.
 @param originalMessage the message to which this notification is related.
 @param code the error code sent by the Server. It can be one of the following: <ul>
 <li><= 0 - the Metadata Adapter has refused the message; the code value is dependent on the specific Metadata Adapter implementation.</li>
 </ul>
 @param error the description of the error sent by the Server.
 */
- (void) client:(nonnull LSLightstreamerClient *)client didDenyMessage:(nonnull NSString *)originalMessage withCode:(NSInteger)code error:(nullable NSString *)error;

/**
 @brief Event handler that is called by Lightstreamer to notify that the related message has been discarded by the Server.
 <br/> This means that the message has not reached the Metadata Adapter and the message next in the sequence is considered enabled for processing.
 @param client the LSLightstreamerClient instance.
 @param originalMessage the message to which this notification is related.
 */
- (void) client:(nonnull LSLightstreamerClient *)client  didDiscardMessage:(nonnull NSString *)originalMessage;

/**
 @brief Event handler that is called by Lightstreamer when the related message has been processed by the Server but the processing has failed for any reason.
 <br/> The level of completion of the processing by the Metadata Adapter cannot be determined.
 @param client the LSLightstreamerClient instance.
 @param originalMessage the message to which this notification is related.
 */
- (void) client:(nonnull LSLightstreamerClient *)client  didFailMessage:(nonnull NSString *)originalMessage;

/**
 @brief Event handler that is called by Lightstreamer when the related message has been processed by the Server with success.
 @param client the LSLightstreamerClient instance.
 @param originalMessage the message to which this notification is related.
 */
- (void) client:(nonnull LSLightstreamerClient *)client  didProcessMessage:(nonnull NSString *)originalMessage;


@end

