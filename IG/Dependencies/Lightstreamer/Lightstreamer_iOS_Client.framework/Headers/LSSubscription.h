//
//  LSSubscription.h
//  Lightstreamer client for iOS UCA
//

#import <Foundation/Foundation.h>


@protocol LSSubscriptionDelegate;


/**
 @brief Class representing a Subscription to be submitted to a Lightstreamer Server.
 <br/> It contains subscription details and the delegates needed to process the real-time data.
 <br/> After the creation, an LSSubscription object is in the "inactive" state. When a Subscription object is subscribed to on a LSLightstreamerClient object, 
 through the LSLightstreamerClient#subscribe: method, its state becomes "active". This means that the client activates a subscription to the required items 
 through Lightstreamer Server and the LSSubscription object begins to receive real-time events.
 <br/> A Subscription can be configured to use either an Item Group or an Item List to specify the items to be subscribed to and using either a Field Schema 
 or Field List to specify the fields.
 <br/> "Item Group" and "Item List" are defined as follows: <ul> 
 <li>"Item Group": an Item Group is a String identifier representing a list of items. Such Item Group has to be expanded into a list of items by the 
 getItems method of the MetadataProvider of the associated Adapter Set. When using an Item Group, items in the subscription are identified by their 
 1-based index within the group.
 <br/> It is possible to configure the LSSubscription to use an "Item Group" using the #itemGroup property.</li>
 <li>"Item List": an Item List is an array of Strings each one representing an item. For the Item List to be correctly interpreted a LiteralBasedProvider or 
 a MetadataProvider with a compatible implementation of getItems has to be configured in the associated Adapter Set.
 <br/> Note that no item in the list can be empty, can contain spaces or can be a number.
 <br/> When using an Item List, items in the subscription are identified by their name or by their 1-based index within the list.
 <br/> It is possible to configure the Subscription to use an "Item List" using the #items property or by specifying it in the constructor.</li> 
 </ul> 
 "Field Schema" and "Field List" are defined as follows: <ul> 
 <li>"Field Schema": a Field Schema is a String identifier representing a list of fields. Such Field Schema has to be expanded into a list of fields by 
 the getFields method of the MetadataProvider of the associated Adapter Set. When using a Field Schema, fields in the subscription are identified by 
 their 1-based index within the schema.
 <br/> It is possible to configure the LSSubscription to use a "Field Schema" using the #fieldSchema property.</li> 
 <li>"Field List": a Field List is an array of Strings each one representing a field. For the Field List to be correctly interpreted a LiteralBasedProvider or 
 a MetadataProvider with a compatible implementation of getFields has to be configured in the associated Adapter Set.
 <br/> Note that no field in the list can be empty or can contain spaces.
 <br/> When using a Field List, fields in the subscription are identified by their name or by their 1-based index within the list.</li> 
 </ul> It is possible to configure the LSSubscription to use a "Field List" using the #fields property or by specifying it in the constructor.
 */
@interface LSSubscription : NSObject


/**
 @brief Creates an object to be used to describe an LSSubscription that is going to be subscribed to through Lightstreamer Server.
 <br/> The object can be supplied to LSLightstreamerClient#subscribe: and LSLightstreamerClient#unsubscribe:, in order to bring the LSSubscription to "active" 
 or back to "inactive" state.
 <br/> Note that all of the methods used to describe the subscription to the server can only be called while the instance is in the "inactive" state; 
 the only exception is #requestedMaxFrequency.
 @param subscriptionMode the subscription mode for the items, required by Lightstreamer Server. Permitted values are: <ul> 
 <li>MERGE</li> 
 <li>DISTINCT</li> 
 <li>RAW</li> 
 <li>COMMAND</li> 
 </ul>
 */
- (nonnull instancetype) initWithSubscriptionMode:(nonnull NSString*)subscriptionMode NS_SWIFT_NAME(init(mode:));

/**
 @brief Creates an object to be used to describe an LSSubscription that is going to be subscribed to through Lightstreamer Server.
 <br/>The object can be supplied to LSLightstreamerClient#subscribe: and LSLightstreamerClient#unsubscribe:, in order to bring the LSSubscription to "active" 
 or back to "inactive" state.
 <br/> Note that all of the methods used to describe the subscription to the server can only be called while the instance is in the "inactive" state; 
 the only exception is #requestedMaxFrequency.
 @param subscriptionMode the subscription mode for the items, required by Lightstreamer Server. Permitted values are: <ul> 
 <li>MERGE</li> 
 <li>DISTINCT</li>
 <li>RAW</li> 
 <li>COMMAND</li> 
 </ul>
 @param item the item name to be subscribed to through Lightstreamer Server.
 @param fields an array of fields for the items to be subscribed to through Lightstreamer Server.
 <br/> It is also possible to specify the "Field List" or "Field Schema" later through #fields and #fieldSchema.
 @throws NSException If no or invalid subscription mode is passed.
 @throws NSException If either the item or the fields array is left nil.
 @throws NSException If the specified "Field List" is not valid; see #fields for details..
 */
- (nonnull instancetype) initWithSubscriptionMode:(nonnull NSString*)subscriptionMode item:(nonnull NSString*)item fields:(nonnull NSArray<NSString*>*)fields NS_SWIFT_NAME(init(mode:item:fields:));

/**
 @brief Creates an object to be used to describe an LSSubscription that is going to be subscribed to through Lightstreamer Server.
 <br/> The object can be supplied to LSLightstreamerClient#subscribe: and LSLightstreamerClient#unsubscribe:, in order to bring the LSSubscription to 
 "active" or back to "inactive" state.
 <br/> Note that all of the methods used to describe the subscription to the server can only be called while the instance is in the "inactive" state; 
 the only exception is #requestedMaxFrequency.
 @param subscriptionMode the subscription mode for the items, required by Lightstreamer Server. Permitted values are: <ul> 
 <li>MERGE</li> 
 <li>DISTINCT</li> 
 <li>RAW</li> 
 <li>COMMAND</li> 
 </ul>
 @param items an array of items to be subscribed to through Lightstreamer server.
 <br/> It is also possible specify the "Item List" or "Item Group" later through #items and #itemGroup.
 @param fields an array of fields for the items to be subscribed to through Lightstreamer Server.
 <br/> It is also possible to specify the "Field List" or "Field Schema" later through #fields and #fieldSchema.
 @throws NSException If no or invalid subscription mode is passed.
 @throws NSException If either the items or the fields array is left nil.
 @throws NSException If the specified "Item List" or "Field List" is not valid; see #items and #fields for details.
 */
- (nonnull instancetype) initWithSubscriptionMode:(nonnull NSString*)subscriptionMode items:(nonnull NSArray<NSString*>*)items fields:(nonnull NSArray<NSString*>*)fields NS_SWIFT_NAME(init(mode:items:fields:));

/**
 @brief Adds a delegate that will receive events from the LSSubscription instance.
 <br/> The same delegate can be added to several different LSSubscription instances.
 A delegate can be added at any time. A call to add a delegate already present will be ignored.
 @param delegate An object that will receive the events as documented in the LSSubscriptionDelegate interface.
 <br/> Note: delegates are stored with weak references: make sure you keep a strong reference to your delegates or they may be released prematurely.
 */
- (void) addDelegate:(nonnull id <LSSubscriptionDelegate>)delegate NS_SWIFT_NAME(add(delegate:));

/**
 @brief Position of the "command" field in a COMMAND Subscription.
 <br/> This property can only be used if the Subscription mode is COMMAND and the LSSubscription was initialized using a "Field Schema".
 <br/> This property can be called at any time after the first LSSubscriptionDelegate#subscriptionDidSubscribe event.
 @throws NSException if the LSSubscription mode is not COMMAND or if the LSSubscriptionDelegate#subscriptionDidSubscribe event for this LSSubscription was 
 not yet fired.
 @throws NSException if a "Field List" was specified.
 */
@property (nonatomic, readonly) NSUInteger commandPosition;

/**
 @brief Name of the second-level Data Adapter (within the Adapter Set used by the current session) that supplies all the second-level items.
 <br/> All the possible second-level items should be supplied in "MERGE" mode with snapshot available.
 <br/> The Data Adapter name is configured on the server side through the "name" attribute of the &lt;data_provider&gt; element, in the "adapters.xml" 
 file that defines the Adapter Set (a missing attribute configures the "DEFAULT" name).
 <br/> Default: the default Data Adapter for the Adapter Set, configured as "DEFAULT" on the Server.
 <br/> This property can only be changed while the LSSubscription instance is in its "inactive" state.
 @throws NSException if the LSSubscription is currently "active".
 @throws NSException if the LSSubscription mode is not "COMMAND".
 */
@property (nonatomic, copy, nullable) NSString *commandSecondLevelDataAdapter;

/**
 @brief The "Field List" to be subscribed to through Lightstreamer Server for the second-level items. It can only be used on COMMAND Subscriptions.
 <br/> Any change to this property will override any "Field List" or "Field Schema" previously specified for the second-level.
 <br/> Setting this property enables the two-level behavior: in synthesis, each time a new key is received on the COMMAND Subscription, the key value is 
 treated as an Item name and an underlying LSSubscription for this Item is created and subscribed to automatically, to feed fields specified by this method. 
 This mono-item LSSubscription is specified through an "Item List" containing only the Item name received. As a consequence, all the conditions provided 
 for subscriptions through Item Lists have to be satisfied. The item is subscribed to in "MERGE" mode, with snapshot request and with the same maximum 
 frequency setting as for the first-level items (including the "unfiltered" case). All other LSSubscription properties are left as the default. When the 
 key is deleted by a DELETE command on the first-level LSSubscription, the associated second-level LSSubscription is also unsubscribed from.
 <br/> Specifying nil as parameter will disable the two-level behavior.
 <br/> This property can only be set while the LSSubscription instance is in its "inactive" state.
 @throws NSException if any of the field names in the "Field List" contains a space or is empty/nil.
 @throws NSException if the LSSubscription is currently "active".
 @throws NSException if the LSSubscription mode is not "COMMAND".
 */
@property (nonatomic, copy, nullable) NSArray *commandSecondLevelFields;

/**
 @brief The "Field Schema" to be subscribed to through Lightstreamer Server for the second-level items. It can only be used on COMMAND Subscriptions.
 <br/> Any change to this property will override any "Field List" or "Field Schema" previously specified for the second-level.
 <br/> Setting this property enables the two-level behavior: in synthesis, each time a new key is received on the COMMAND Subscription, the key value is 
 treated as an Item name and an underlying Subscription for this Item is created and subscribed to automatically, to feed fields specified by this method. 
 This mono-item LSSubscription is specified through an "Item List" containing only the Item name received. As a consequence, all the conditions provided 
 for subscriptions through Item Lists have to be satisfied. The item is subscribed to in "MERGE" mode, with snapshot request and with the same maximum 
 frequency setting as for the first-level items (including the "unfiltered" case). All other LSSubscription properties are left as the default. When the 
 key is deleted by a DELETE command on the first-level LSSubscription, the associated second-level LSSubscription is also unsubscribed from.
 <br/> Specifying nil as parameter will disable the two-level behavior.
 <br/> This property can only be set while the LSSubscription instance is in its "inactive" state.
 @throws NSException if the LSSubscription is currently "active".
 @throws NSException if the LSSubscription mode is not "COMMAND".
 */
@property (nonatomic, copy, nullable) NSString *commandSecondLevelFieldSchema;

/**
 @brief Returns the latest value received for the specified item/key/field combination. This method can only be used if the Subscription mode is COMMAND.
 Subscriptions with two-level behavior are also supported, hence the specified field can be either a first-level or a second-level one.
 <br/> It is suggested to consume real-time data by implementing and adding a proper LSSubscriptionDelegate rather than probing this method.
 <br/> Note that internal data is cleared when the LSSubscription is unsubscribed from.
 @param itemPos the 1-based position of an item within the configured "Item Group" or "Item List"
 @param key the value of a key received on the COMMAND subscription.
 @param fieldPos the 1-based position of a field within the configured "Field Schema" or "Field List"
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the specified item position or field position is out of bounds.
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the LSSubscription mode is not COMMAND.
 @return the current value for the specified field of the specified key within the specified item (possibly nil), or nil if the specified key has not
 been added yet (note that it might have been added and then deleted).
 <br/> Returns nil also if LSLightstreamerClient#limitExceptionsUse is YES and the specified item position or field position is out of bounds,
 or the LSSubscription mode is not COMMAND.
 */
- (nullable NSString *) commandValueWithItemPos:(NSUInteger)itemPos key:(nonnull NSString *)key fieldPos:(NSUInteger)fieldPos;

/**
 @brief Returns the latest value received for the specified item/key/field combination. This method can only be used if the Subscription mode is COMMAND. 
 Subscriptions with two-level behavior are also supported, hence the specified field can be either a first-level or a second-level one.
 <br/> It is suggested to consume real-time data by implementing and adding a proper LSSubscriptionDelegate rather than probing this method.
 <br/> Note that internal data is cleared when the LSSubscription is unsubscribed from.
 @param itemPos the 1-based position of an item within the configured "Item Group" or "Item List"
 @param key the value of a key received on the COMMAND subscription.
 @param fieldName a item in the configured "Field List"
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and an invalid field name is specified.
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the specified item position is out of bounds.
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the LSSubscription mode is not COMMAND.
 @return the current value for the specified field of the specified key within the specified item (possibly nil), or nil if the specified key has not
 been added yet (note that it might have been added and then deleted).
 <br/> Returns nil also if LSLightstreamerClient#limitExceptionsUse is YES and an invalid field name is specified, the specified item position is out of bounds
 or the LSSubscription mode is not COMMAND.
 */
- (nullable NSString *) commandValueWithItemPos:(NSUInteger)itemPos key:(nonnull NSString *)key fieldName:(nonnull NSString *)fieldName;

/**
 @brief Returns the latest value received for the specified item/key/field combination. This method can only be used if the Subscription mode is COMMAND. 
 Subscriptions with two-level behavior are also supported, hence the specified field can be either a first-level or a second-level one.
 <br/> It is suggested to consume real-time data by implementing and adding a proper LSSubscriptionDelegate rather than probing this method.
 <br/> Note that internal data is cleared when the LSSubscription is unsubscribed from.
 @param itemName an item in the configured "Item List"
 @param key the value of a key received on the COMMAND subscription.
 @param fieldPos the 1-based position of a field within the configured "Field Schema" or "Field List"
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and an invalid item name is specified.
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the specified field position is out of bounds.
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the LSSubscription mode is not COMMAND.
 @return the current value for the specified field of the specified key within the specified item (possibly nil), or nil if the specified key has not
 been added yet (note that it might have been added and then deleted). 
 <br/> Returns nil also if LSLightstreamerClient#limitExceptionsUse is YES and an invalid item name is specified, the specified field position is out of bounds 
 or the LSSubscription mode is not COMMAND.
 */
- (nullable NSString *) commandValueWithItemName:(nonnull NSString *)itemName key:(nonnull NSString *)key fieldPos:(NSUInteger)fieldPos;

/**
 @brief Returns the latest value received for the specified item/key/field combination. This method can only be used if the Subscription mode is COMMAND. 
 Subscriptions with two-level behavior are also supported, hence the specified field can be either a first-level or a second-level one.
 <br/> It is suggested to consume real-time data by implementing and adding a proper LSSubscriptionDelegate rather than probing this method.
 <br/> Note that internal data is cleared when the LSSubscription is unsubscribed from.
 @param itemName an item in the configured "Item List"
 @param key the value of a key received on the COMMAND subscription.
 @param fieldName a item in the configured "Field List"
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and an invalid item name or field name is specified.
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the LSSubscription mode is not COMMAND.
 @return the current value for the specified field of the specified key within the specified item (possibly nil), or nil if the specified key has not
 been added yet (note that it might have been added and then deleted).
 <br/> Returns nil also if LSLightstreamerClient#limitExceptionsUse is YES and an invalid item name or field name is specified,
 or the LSSubscription mode is not COMMAND.
 */
- (nullable NSString *) commandValueWithItemName:(nonnull NSString *)itemName key:(nonnull NSString *)key fieldName:(nonnull NSString *)fieldName;

/**
 @brief Name of the Data Adapter (within the Adapter Set used by the current session) that supplies all the items for this Subscription.
 <br/> The Data Adapter name is configured on the server side through the "name" attribute of the "data_provider" element, in the "adapters.xml" file 
 that defines the Adapter Set (a missing attribute configures the "DEFAULT" name).
 <br/> Note that if more than one Data Adapter is needed to supply all the items in a set of items, then it is not possible to group all the items of 
 the set in a single Subscription. Multiple LSSubscriptions have to be defined.
 <br/>Default: the default Data Adapter for the Adapter Set, configured as "DEFAULT" on the Server.
 <br/> This property can only be set while the LSSubscription instance is in its "inactive" state.
 @throws NSException if the LSSubscription is currently "active".
 */
@property (nonatomic, copy, nullable) NSString *dataAdapter;

/**
 @brief The "Field List" to be subscribed to through Lightstreamer Server.
 <br/> Any change to this property will override any "Field List" or "Field Schema" previously specified.
 <br/> This property can only be set while the LSSubscription instance is in its "inactive" state.
 @throws NSException if any of the field names in the list contains a space or is empty/nil.
 @throws NSException if the LSSubscription is currently "active".
 @throws NSException if the LSSubscription was initialized with a "Field Schema" or was not initialized at all.
 */
@property (nonatomic, copy, nullable) NSArray *fields;

/**
 @brief The "Field Schema" to be subscribed to through Lightstreamer Server.
 <br/> Any change to this property will override any "Field List" or "Field Schema" previously specified.
 <br/> This property can only be set while the LSSubscription instance is in its "inactive" state.
 <br/> NOTE: In the current version, the implementation is incomplete. If the subscription is in COMMAND mode changing this property will result in a 
 LSSubscriptionDelegate#subscription:didFailWithError:message: with code 23.
 @throws NSException if the LSSubscription is currently "active".
 @throws NSException if the LSSubscription was initialized with a "Field List" or was not initialized at all.
 */
@property (nonatomic, copy, nullable) NSString *fieldSchema;

/**
 @brief The "Item Group" to be subscribed to through Lightstreamer Server.
 <br/> Any change to this property will override any "Item List" or "Item Group" previously specified.
 <br/> This property can only be set while the LSSubscription instance is in its "inactive" state.
 @throws NSException if the Subscription is currently "active".
 @throws NSException if the Subscription was initialized with an "Item List" or was not initialized at all.
 */
@property (nonatomic, copy, nullable) NSString *itemGroup;

/**
 @brief The "Item List" to be subscribed to through Lightstreamer Server.
 <br/> Any change to this property will override any "Item List" or "Item Group" previously specified.
 <br/> This property can only be set while the LSSubscription instance is in its "inactive" state.
 @throws NSException if any of the item names in the "Item List" contains a space or is a number or is empty/nil.
 @throws NSException if the LSSubscription is currently "active".
 @throws NSException if the LSSubscription was initialized with an "Item Group" or was not initialized at all.
 */
@property (nonatomic, copy, nullable) NSArray *items;

/**
 @brief Position of the "key" field in a COMMAND Subscription.
 <br/> This property can only be accessed if the LSSubscription mode is COMMAND and the LSSubscription was initialized using a "Field Schema".
 <br/> This method can be called at any time.
 @throws NSException if the LSSubscription mode is not COMMAND or if the LSSubscriptionDelegate#subscriptionDidSubscribe: event for this LSSubscription was 
 not yet fired.
 */
@property (nonatomic, readonly) NSUInteger keyPosition;

/**
 @brief List containing the LSSubscriptionDelegate instances that were added to this client.
 */
@property (nonatomic, readonly, nonnull) NSArray *delegates;

/**
 @brief The mode specified for this LSSubscription.
 <br/> This property can be accessed at any time.
 */
@property (nonatomic, readonly, nonnull) NSString *mode;

/**
 @brief Length to be requested to Lightstreamer Server for the internal queuing buffers for the items in the Subscription.
 <br/> A Queuing buffer is used by the Server to accumulate a burst of updates for an item, so that they can all be sent to the client, despite of bandwidth 
 or frequency limits. It can be used only when the subscription mode is MERGE or DISTINCT and unfiltered dispatching has not been requested. If the string 
 "unlimited" is supplied, then the buffer length is decided by the Server (the check is case insensitive). Note that the Server may pose an upper limit 
 on the size of its internal buffers.
 <br/> Default: nil, meaning to not request a buffer size to the server; this means that the buffer size will be 1 for MERGE subscriptions and 
 "unlimited" for DISTINCT subscriptions. See the "General Concepts" document for further details.
 <br/> This property can only be changed while the LSSubscription instance is in its "inactive" state.
 @throws NSException if the LSSubscription is currently "active".
 @throws NSException if the specified value is not nil nor "unlimited" nor a valid positive integer number.
 */
@property (nonatomic, copy, nullable) NSString *requestedBufferSize;

/**
 @brief Maximum update frequency to be requested to Lightstreamer Server for all the items in the LSSubscription.
 <br/> The maximum update frequency is expressed in updates per second and applies for each item in the LSSubscription; for instance, with a setting of 0.5, 
 for each single item, no more than one update every 2 seconds will be received. If the string "unlimited" is supplied, then the maximum frequency is decided 
 by the Server. It is also possible to supply the string "unfiltered", to ask for unfiltered dispatching, if it is allowed for the items, or a nil value to 
 avoid sending any frequency request to the server. The check for the string constants is case insensitive.
 <br/> It can be used only if the Subscription mode is MERGE, DISTINCT or COMMAND (in the latter case, the frequency limitation applies to the UPDATE events
 for each single key).
 <br/> Note that frequency limits on the items can also be set on the server side and this request can only be issued in order to furtherly reduce the 
 frequency, not to rise it beyond these limits.
 <br/> This property can also be set to request unfiltered dispatching for the items in the Subscription. However, unfiltered dispatching requests may
 be refused if any frequency limit is posed on the server side for some item.
 <br/> A further global frequency limit is also imposed by the Server, if it is running in Presto edition; this specific limit also applies to RAW mode and 
 to unfiltered dispatching.
 <br/> A further global frequency limit is also imposed by the Server, if it is running in Allegro edition; this specific limit also applies to RAW mode and 
 to unfiltered dispatching.
 <br/> A further global frequency limit is also imposed by the Server, if it is running in Moderato edition; this specific limit also applies to RAW mode and 
 to unfiltered dispatching.
 <br/> Default: nil, meaning to not request any frequency limit to the server. As a consequence the server will try to not apply any frequency limit to 
 the subscription (i.e.: "unlimited", see the "General Concepts" document for further details)
 <br/> This method can can be called at any time with some differences based on the LSSubscription status: <ul> 
 <li>If the LSSubscription instance is in its "inactive" state then this property can be changed at will.</li>
 <li>If the LSSubscription instance is in its "active" state then this property can still be changed unless its current or target value is "unfiltered" or nil. 
 Also if the Subscription instance is in its "active" state and the connection to the server is currently open, then a request to change the frequency of the 
 LSSubscription on the fly is sent to the server.</li> 
 </ul>
 @throws NSException if the LSSubscription is currently "active" and the current value of this property is nil or "unfiltered".
 @throws NSException if the LSSubscription is currently "active" and the given parameter is nil or "unfiltered".
 @throws NSException if the specified value is not nil nor one of the special "unlimited" and "unfiltered" values nor a valid positive number.
 */
@property (nonatomic, copy, nullable) NSString *requestedMaxFrequency;

/**
 @brief Enables/disables snapshot delivery request for the items in the LSSubscription.
 <br/> The snapshot delivery is expressed as "yes"/"no" to request/not request snapshot delivery (the check is case insensitive). If the LSSubscription mode is
 DISTINCT, instead of "yes", it is also possible to supply a number, to specify the requested length of the snapshot (though the length of the received snapshot 
 may be less than requested, because of insufficient data or server side limits); passing "yes"  means that the snapshot length should be determined only by the 
 Server. Nil is also a valid value; if specified no snapshot preference will be sent to the server that will decide itself whether or not to send any snapshot.
 <br/> The snapshot can be requested only if the LSSubscription mode is MERGE, DISTINCT or COMMAND.
 <br/> Default: "yes" if the LSSubscription mode is not "RAW", nil otherwise.
 <br/> This property can only be changed while the LSSubscription instance is in its "inactive" state.
 @throws NSException if the LSSubscription is currently "active".
 @throws NSException if the specified value is not "yes" nor "no" nor nil nor a valid integer positive number.
 @throws NSException if the specified value is not compatible with the mode of the Subscription: <ul> 
 <li>In case of a RAW LSSubscription only nil is a valid value;</li>
 <li>In case of a non-DISTINCT LSSubscription only nil, "yes" and "no" are valid values.</li> 
 </ul>
 */
@property (nonatomic, copy, nullable) NSString *requestedSnapshot;

/**
 @brief The selector name for all the items in the LSSubscription.
 <br/> The selector is a filter on the updates received. It is executed on the Server and implemented by the Metadata Adapter.
 <br/> Default: nil (no selector).
 <br/> This property can only be changed while the LSSubscription instance is in its "inactive" state.
 @throws NSException if the Subscription is currently "active".
 */
@property (nonatomic, copy, nullable) NSString *selector;

/**
 @brief Returns the latest value received for the specified item/field pair.
 <br/> It is suggested to consume real-time data by implementing and adding a proper LSSubscriptionDelegate rather than probing this method.
 <br/> In case of COMMAND LSSubscriptions, the value returned by this method may be misleading, as in COMMAND mode all the keys received, being part of the same 
 item, will overwrite each other; for COMMAND LSSubscriptions, use #commandValueWithItemPos:key:fieldPos: instead.
 <br/> Note that internal data is cleared when the LSSubscription is unsubscribed from.
 <br/> This method can be called at any time; if called to retrieve a value that has not been received yet, then it will return nil.
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the specified item position or field position is out of bounds.
 @param itemPos the 1-based position of an item within the configured "Item Group" or "Item List"
 @param fieldPos the 1-based position of a field within the configured "Field Schema" or "Field List"
 @return the current value for the specified field of the specified item (possibly nil), or nil if no value has been received yet.
 <br/> Returns nil also if LSLightstreamerClient#limitExceptionsUse is YES and the specified item position or field position is out of bounds.
 */
- (nullable NSString *) valueWithItemPos:(NSUInteger)itemPos fieldPos:(NSUInteger)fieldPos;

/**
 @brief Returns the latest value received for the specified item/field pair.
 <br/> It is suggested to consume real-time data by implementing and adding a proper LSSubscriptionDelegate rather than probing this method.
 <br/> In case of COMMAND LSSubscriptions, the value returned by this method may be misleading, as in COMMAND mode all the keys received, being part of the same 
 item, will overwrite each other; for COMMAND Subscriptions, use #commandValueWithItemPos:key:fieldName: instead.
 <br/> Note that internal data is cleared when the Subscription is unsubscribed from.
 <br/> This method can be called at any time; if called to retrieve a value that has not been received yet, then it will return nil.
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and an invalid field name is specified.
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the specified item position is out of bounds.
 @param itemPos the 1-based position of an item within the configured "Item Group" or "Item List"
 @param fieldName a item in the configured "Field List"
 @return the current value for the specified field of the specified item (possibly nil), or nil if no value has been received yet.
 <br/> Returns nil also if LSLightstreamerClient#limitExceptionsUse is YES and an invalid field name is specified or the specified item position is out of bounds.
 */
- (nullable NSString *) valueWithItemPos:(NSUInteger)itemPos fieldName:(nonnull NSString *)fieldName;

/**
 @brief Returns the latest value received for the specified item/field pair.
 <br/> It is suggested to consume real-time data by implementing and adding a proper LSSubscriptionDelegate rather than probing this method.
 <br/> In case of COMMAND LSSubscriptions, the value returned by this method may be misleading, as in COMMAND mode all the keys received, being part of the same
 item, will overwrite each other; for COMMAND Subscriptions, use #commandValueWithItemName:key:fieldPos: instead.
 <br/> Note that internal data is cleared when the LSSubscription is unsubscribed from.
 <br/>This method can be called at any time; if called to retrieve a value that has not been received yet, then it will return nil.
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and an invalid item name is specified.
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the specified field position is out of bounds.
 @param itemName an item in the configured "Item List"
 @param fieldPos the 1-based position of a field within the configured "Field Schema" or "Field List"
 @return the current value for the specified field of the specified item (possibly nil), or nil if no value has been received yet.
 <br/> Returns nil also if LSLightstreamerClient#limitExceptionsUse is YES and an invalid item name is specified or the specified field position is out of bounds.
 */
- (nullable NSString *) valueWithItemName:(nonnull NSString *)itemName fieldPos:(NSUInteger)fieldPos;

/**
 @brief Returns the latest value received for the specified item/field pair.
 <br/> It is suggested to consume real-time data by implementing and adding a proper LSSubscriptionDelegate rather than probing this method.
 <br/> In case of COMMAND Subscriptions, the value returned by this method may be misleading, as in COMMAND mode all the keys received, being part of the same 
 item, will overwrite each other; for COMMAND LSSubscriptions, use #commandValueWithItemName:key:fieldName: instead.
 <br/> Note that internal data is cleared when the LSSubscription is unsubscribed from.
 <br/> This method can be called at any time; if called to retrieve a value that has not been received yet, then it will return nil.
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and an invalid item name or field name is specified.
 @param itemName an item in the configured "Item List"
 @param fieldName a item in the configured "Field List"
 @return the current value for the specified field of the specified item (possibly nil), or nil if no value has been received yet.
 <br/> Returns nil also if LSLightstreamerClient#limitExceptionsUse is YES and an invalid item name or field name is specified.
 */
- (nullable NSString *) valueWithItemName:(nonnull NSString *)itemName fieldName:(nonnull NSString *)fieldName;

/**
 @brief Checks if the Subscription is currently "active" or not.
 <br/> Most of the Subscription properties cannot be modified if a LSSubscription is "active".
 <br/> The status of a Subscription is changed to "active" through the LSLightstreamerClient#subscribe: method and back to "inactive" through the 
 LSLightstreamerClient#unsubscribe: one.
 <br/> This property can be accessed at any time.
 @return YES/NO if the Subscription is "active" or not.
 */
@property (nonatomic, readonly, getter=isActive) BOOL active;

/**
 @brief Checks if the LSSubscription is currently subscribed to through the server or not.
 <br/> This flag is switched to YES by server sent LSSubscription events, and back to NO in case of client disconnection, 
 LSLightstreamerClient#unsubscribe: calls and server sent unsubscription events.
 <br/> This property can be accessed at any time.
 @return YES/NO if the LSSubscription is subscribed to through the server or not.
 */
@property (nonatomic, readonly, getter=isSubscribed) BOOL subscribed;

/**
 @brief Removes a delegate from the LSSubscription instance so that it will not receive events anymore.
 <br/> A delegate can be removed at any time.
 @param delegate the delegate to be removed.
 */
- (void) removeDelegate:(nonnull id <LSSubscriptionDelegate>)delegate NS_SWIFT_NAME(remove(delegate:));


@end
