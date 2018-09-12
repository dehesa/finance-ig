//
//  LSSubscriptionDelegate.h
//  Lightstreamer client for iOS UCA
//

#import <Foundation/Foundation.h>


@class LSSubscription;
@class LSItemUpdate;


/**
 @brief Interface to be implemented to receive LSSubscription events comprehending notifications of subscription/unsubscription, updates, errors and others.
 <br/> Events for these delegates are dispatched by a different thread than the one that generates them. This means that, upon reception of an event, 
 it is possible that the internal state of the client has changed. On the other hand, all the notifications for a single LSLightstreamerClient, including 
 notifications to LSClientDelegate s, LSSubscriptionDelegate s and LSClientMessageDelegate s will be dispatched by the same thread.
 */
@protocol LSSubscriptionDelegate <NSObject>


@optional

/**
 @brief Event handler that is called by Lightstreamer each time a request to clear the snapshot pertaining to an item in the LSSubscription has been 
 received from the Server.
 <br/> More precisely, this kind of request can occur in two cases: <ul> 
 <li>For an item delivered in COMMAND mode, to notify that the state of the item becomes empty; this is equivalent to receiving an update carrying a 
 DELETE command once for each key that is currently active.</li> 
 <li>For an item delivered in DISTINCT mode, to notify that all the previous updates received for the item should be considered as obsolete; hence, if the 
 delegate were showing a list of recent updates for the item, it should clear the list in order to keep a coherent view.</li> 
 </ul> 
 <br/> Note that, if the involved Subscription has a two-level behavior enabled, the notification refers to the first-level item (which is in COMMAND mode). 
 This kind of notification is not possible for second-level items (which are in MERGE mode). This event can be sent by the Lightstreamer Server since version 6.0.
 <br/> NOTE: This method is only predisposed for forthcoming extensions. In the current version, when a snapshot clearing is requested on the Server side, nothing is 
 received for items delivered in DISTINCT mode, whereas, for COMMAND mode, the Server sends all DELETE events needed to clear the snapshot.
 @param subscription the LSSubscription involved.
 @param itemName name of the involved item. If the LSSubscription was initialized using an "Item Group" then a nil value is supplied.
 @param itemPos 1-based position of the item within the "Item List" or "Item Group".
 */
- (void) subscription:(nonnull LSSubscription *)subscription didClearSnapshotForItemName:(nullable NSString *)itemName itemPos:(NSUInteger)itemPos;

/**
 @brief Event handler that is called by Lightstreamer to notify that, due to internal resource limitations, Lightstreamer Server dropped one or more updates 
 for an item that was subscribed to as a second-level subscription.
 <br/> Such notifications are sent only if the LSSubscription was configured in unfiltered mode (second-level items are always in "MERGE" mode and inherit 
 the frequency configuration from the first-level Subscription).
 <br/> By implementing this method it is possible to perform recovery actions.
 @param subscription the LSSubscription involved.
 @param lostUpdates the number of consecutive updates dropped for the item.
 @param key the value of the key that identifies the second-level item.
 */
- (void) subscription:(nonnull LSSubscription *)subscription didLoseUpdates:(NSUInteger)lostUpdates forCommandSecondLevelItemWithKey:(nonnull NSString *)key;

/**
 @brief Event handler that is called when the Server notifies an error on a second-level subscription.
 <br/> By implementing this method it is possible to perform recovery actions.
 @param code The error code sent by the Server. It can be one of the following: <ul> <li>14 - the key value is not a valid name for the Item to be subscribed; only in this case, the error is detected directly by the library before issuing the actual request to the Server</li> <li>17 - bad Data Adapter name or default Data Adapter not defined for the current Adapter Set</li> <li>20 - session interrupted</li> <li>21 - bad Group name</li> <li>22 - bad Group name for this Schema</li> <li>23 - bad Schema name <li>24 - mode not allowed for an Item <li>25 - bad Selector name <li>26 - unfiltered dispatching not allowed for an Item, because a frequency limit is associated to the item</li> <li>27 - unfiltered dispatching not supported for an Item, because a frequency prefiltering is applied for the item</li> <li>28 - unfiltered dispatching is not allowed by the current license terms (for special licenses only)</li> <li>29 - RAW mode is not allowed by the current license terms (for special licenses only)</li> <li><= 0 - the Metadata Adapter has refused the subscription or unsubscription request; the code value is dependent on the specific Metadata Adapter implementation</li> </ul>
 @param subscription the LSSubscription involved.
 @param message The description of the error sent by the Server; it can be nil.
 @param key The value of the key that identifies the second-level item.
 */
- (void) subscription:(nonnull LSSubscription *)subscription didFailWithErrorCode:(NSInteger)code message:(nullable NSString *)message forCommandSecondLevelItemWithKey:(nonnull NSString *)key;

/**
 @brief Event handler that is called by Lightstreamer to notify that all snapshot events for an item in the LSSubscription have been received, so that 
 real time events are now going to be received.
 <br/> The received snapshot could be empty. Such notifications are sent only if the items are delivered in DISTINCT or COMMAND subscription mode and 
 snapshot information was indeed requested for the items. By implementing this method it is possible to perform actions which require that all the initial 
 values have been received.
 <br/> Note that, if the involved LSSubscription has a two-level behavior enabled, the notification refers to the first-level item (which is in COMMAND mode). 
 Snapshot-related updates for the second-level items (which are in MERGE mode) can be received both before and after this notification.
 @param subscription the LSSubscription involved.
 @param itemName name of the involved item. If the Subscription was initialized using an "Item Group" then a nil value is supplied.
 @param itemPos 1-based position of the item within the "Item List" or "Item Group".
 */
- (void) subscription:(nonnull LSSubscription *)subscription didEndSnapshotForItemName:(nullable NSString *)itemName itemPos:(NSUInteger)itemPos;

/**
 @brief Event handler that is called by Lightstreamer to notify that, due to internal resource limitations, Lightstreamer Server dropped one or more updates 
 for an item in the Subscription.
 <br/> Such notifications are sent only if the items are delivered in an unfiltered mode; this occurs if the subscription mode is: <ul> 
 <li>RAW</li> 
 <li>MERGE or DISTINCT, with unfiltered dispatching specified</li> 
 <li>COMMAND, with unfiltered dispatching specified</li> 
 <li>COMMAND, without unfiltered dispatching specified (in this case, notifications apply to ADD and DELETE events only)</li> 
 </ul> 
 <br/> By implementing this method it is possible to perform recovery actions.
 @param subscription the LSSubscription involved.
 @param lostUpdates The number of consecutive updates dropped for the item.
 @param itemName name of the involved item. If the Subscription was initialized using an "Item Group" then a nil value is supplied.
 @param itemPos 1-based position of the item within the "Item List" or "Item Group".
 */
- (void) subscription:(nonnull LSSubscription *)subscription didLoseUpdates:(NSUInteger)lostUpdates forItemName:(nullable NSString *)itemName itemPos:(NSUInteger)itemPos;

/**
 @brief Event handler that is called by Lightstreamer each time an update pertaining to an item in the LSSubscription has been received from the Server.
 @param subscription the LSSubscription involved.
 @param itemUpdate a value object containing the updated values for all the fields, together with meta-information about the update itself and some helper
 methods that can be used to iterate through all or new values.
 */
- (void) subscription:(nonnull LSSubscription *)subscription didUpdateItem:(nonnull LSItemUpdate *)itemUpdate;

/**
 @brief Event handler that receives a notification when the LSSubscriptionDelegate instance is removed from a LSSubscription through LSSubscription#removeDelegate:.
 <br/> This is the last event to be fired on the delegate.
 @param subscription the LSSubscription this instance was removed from.
 */
- (void) subscriptionDidRemoveDelegate:(nonnull LSSubscription *)subscription;

/**
 @brief Event handler that receives a notification when the LSSubscriptionDelegate instance is added to a LSSubscription through 
 LSSubscription#addDelegate:.
 <br/> This is the first event to be fired on the delegate.
 @param subscription the LSSubscription this instance was added to.
 */
- (void) subscriptionDidAddDelegate:(nonnull LSSubscription *)subscription;

/**
 @brief Event handler that is called by Lightstreamer to notify that a LSSubscription has been successfully subscribed to through the Server.
 <br/> This can happen multiple times in the life of a LSSubscription instance, in case the Subscription is performed multiple times through 
 LSLightstreamerClient#unsubscribe: and LSLightstreamerClient#subscribe:. This can also happen multiple times in case of automatic recovery after a connection 
 restart.
 <br/> This notification is always issued before the other ones related to the same subscription. It invalidates all data that has been received previously.
 <br/> Note that two consecutive calls to this method are not possible, as before a second #subscriptionDidSubscribe: event is fired an #subscriptionDidUnsubscribe: 
 event is eventually fired.
 <br/> If the involved LSSubscription has a two-level behavior enabled, second-level subscriptions are not notified.
 @param subscription the LSSubscription involved.
 */
- (void) subscriptionDidSubscribe:(nonnull LSSubscription *)subscription;

/**
 @brief Event handler that is called when the Server notifies an error on a LSSubscription.
 <br/> By implementing this method it is possible to perform recovery actions.
 <br/> Note that, in order to perform a new subscription attempt, LSLightstreamerClient#unsubscribe: and LSLightstreamerClient#subscribe: should be issued 
 again, even if no change to the LSSubscription attributes has been applied.
 @param subscription the LSSubscription involved.
 @param code The error code sent by the Server. It can be one of the following: <ul>
 <li>17 - bad Data Adapter name or default Data Adapter not defined for the current Adapter Set</li> 
 <li>20 - session interrupted</li> 
 <li>21 - bad Group name</li> 
 <li>22 - bad Group name for this Schema</li> 
 <li>23 - bad Schema name 
 <li>24 - mode not allowed for an Item 
 <li>25 - bad Selector name 
 <li>26 - unfiltered dispatching not allowed for an Item, because a frequency limit is associated to the item</li> 
 <li>27 - unfiltered dispatching not supported for an Item, because a frequency prefiltering is applied for the item</li> 
 <li>28 - unfiltered dispatching is not allowed by the current license terms (for special licenses only)</li> 
 <li>29 - RAW mode is not allowed by the current license terms (for special licenses only)</li> 
 <li>30 - subscriptions are not allowed by the current license terms (for special licenses only)</li> 
 <li><= 0 - the Metadata Adapter has refused the subscription or unsubscription request; the code value is dependent on the specific Metadata 
 Adapter implementation</li> 
 </ul>
 @param message The description of the error sent by the Server; it can be nil.
 */
- (void) subscription:(nonnull LSSubscription *)subscription didFailWithErrorCode:(NSInteger)code message:(nullable NSString *)message;

/**
 @brief Event handler that is called by Lightstreamer to notify that a LSSubscription has been successfully unsubscribed from.
 <br/> This can happen multiple times in the life of a LSSubscription instance, in case the LSSubscription is performed multiple times through 
 LSLightstreamerClient#unsubscribe: and LSLightstreamerClient#subscribe:. This can also happen multiple times in case of automatic recovery after a 
 connection restart.
 <br/> After this notification no more events can be received until a new #onSubscription event.
 <br/> Note that two consecutive calls to this method are not possible, as before a second #subscriptionDidUnsubscribe: event is fired an #subscriptionDidSubscribe: event
 is eventually fired.
 <br/> If the involved LSSubscription has a two-level behavior enabled, second-level unsubscriptions are not notified.
 */
- (void) subscriptionDidUnsubscribe:(nonnull LSSubscription *)subscription;


@end
