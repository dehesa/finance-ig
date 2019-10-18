//
//  LSItemUpdate.h
//  Lightstreamer client for iOS UCA
//

#import <Foundation/Foundation.h>


/**
 @brief Contains all the information related to an update of the field values for an item.
 <br/> It reports all the new values of the fields.
 <br/> <b>COMMAND LSSubscription</b>
 <br/> If the involved LSSubscription is a COMMAND LSSubscription, then the values for the current update are meant as relative to the same key.
 <br/> Moreover, if the involved LSSubscription has a two-level behavior enabled, then each update may be associated with either a first-level or a 
 second-level item. In this case, the reported fields are always the union of the first-level and second-level fields and each single update can 
 only change either the first-level or the second-level fields (but for the "command" field, which is first-level and is always set to "UPDATE" upon 
 a second-level update); note that the second-level field values are always nil until the first second-level update occurs). When the two-level behavior
 is enabled, in all methods where a field name has to be supplied, the following convention should be followed:<ul> 
 <li>The field name can always be used, both for the first-level and the second-level fields. In case of name conflict, the first-level field is meant.</li> 
 <li>The field position can always be used; however, the field positions for the second-level fields start at the highest position of the first-level 
 field list + 1. If a field schema had been specified for either first-level or second-level Subscriptions, then client-side knowledge of the first-level 
 schema length would be required.</li> 
 </ul>
 */
@interface LSItemUpdate : NSObject


/**
 @brief Values for each field changed with the last server update. The related field name is used as key for the values in the map. 
 <br/> Note that if the LSSubscription mode of the involved Subscription is COMMAND, then changed fields are meant as relative to the previous update 
 for the same key. On such tables if a DELETE command is received, all the fields, excluding the key field, will be present as changed, with nil value. 
 All of this is also true on tables that have the two-level behavior enabled, but in case of DELETE commands second-level fields will not be iterated.
 @throws NSException if the LSSubscription was initialized using a field schema.
 */
@property (nonatomic, readonly, nonnull) NSDictionary *changedFields;

/**
 @brief Values for each field changed with the last server update. The 1-based field position within the field schema or field list is used as key for 
 the values in the map. 
 <br/> Note that if the LSSubscription mode of the involved Subscription is COMMAND, then changed fields are meant as relative to the previous update 
 for the same key. On such tables if a DELETE command is received, all the fields, excluding the key field, will be present as changed, with nil value. 
 All of this is also true on tables that have the two-level behavior enabled, but in case of DELETE commands second-level fields will not be iterated.
 */
@property (nonatomic, readonly, nonnull) NSDictionary *changedFieldsByPositions;

/**
 @brief Values for each field in the LSSubscription. The related field name is used as key for the values in the map.
 @throws NSException if the LSSubscription was initialized using a field schema.
 */
@property (nonatomic, readonly, nonnull) NSDictionary *fields;

/**
 @brief Values for each field in the LSSubscription. The 1-based field position within the field schema or field list is used as key for the values in the map.
 */
@property (nonatomic, readonly, nonnull) NSDictionary *fieldsByPositions;

/**
 @brief The name of the item to which this update pertains.
 <br/> The name will be nil if the related LSSubscription was initialized using an "Item Group".
 */
@property (nonatomic, readonly, nullable) NSString *itemName;

/**
 @brief The 1-based position in the "Item List" or "Item Group" of the item to which this update pertains.
 */
@property (nonatomic, readonly) NSUInteger itemPos;

/**
 @brief Returns the current value for the specified field
 @param fieldPos The 1-based position of the field within the "Field List" or "Field Schema".
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the specified field is not part of the LSSubscription.
 @return The value of the specified field; it can be nil in the following cases:<ul>
 <li>a nil value has been received from the Server, as nil is a possible value for a field;</li> 
 <li>no value has been received for the field yet;</li> 
 <li>the item is subscribed to with the COMMAND mode and a DELETE command is received (only the fields used to carry key and command informations are valued).</li> 
 <li>LSLightstreamerClient#limitExceptionsUse is YES and the specified field is not part of the LSSubscription.</li>
 </ul>
 */
- (nullable NSString *) valueWithFieldPos:(NSUInteger)fieldPos;

/**
 @brief Returns the current value for the specified field
 @param fieldName The field name as specified within the "Field List".
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the specified field is not part of the LSSubscription.
 @return The value of the specified field; it can be nil in the following cases:<ul> 
 <li>a nil value has been received from the Server, as nil is a possible value for a field;</li> 
 <li>no value has been received for the field yet;</li> 
 <li>the item is subscribed to with the COMMAND mode and a DELETE command is received (only the fields used to carry key and command informations are valued).</li> 
 <li>LSLightstreamerClient#limitExceptionsUse is YES and the specified field is not part of the LSSubscription.</li>
 </ul>
 */
- (nullable NSString *) valueWithFieldName:(nonnull NSString *)fieldName;

/**
 @brief Tells whether the current update belongs to the item snapshot (which carries the current item state at the time of Subscription).
 <br/> Snapshot events are sent only if snapshot information was requested for the items through LSSubscription#requestedSnapshot and precede the real time events. 
 Snapshot informations take different forms in different subscription modes and can be spanned across zero, one or several update events. In particular: <ul> 
 <li>if the item is subscribed to with the RAW subscription mode, then no snapshot is sent by the Server;</li> 
 <li>if the item is subscribed to with the MERGE subscription mode, then the snapshot consists of exactly one event, carrying the current value for all fields;</li> 
 <li>if the item is subscribed to with the DISTINCT subscription mode, then the snapshot consists of some of the most recent updates; these updates are as 
 many as specified through LSSubscription#requestedSnapshot, unless fewer are available;</li> 
 <li>if the item is subscribed to with the COMMAND subscription mode, then the snapshot consists of an "ADD" event for each key that is currently present.</li> 
 </ul> 
 <br/> Note that, in case of two-level behavior, snapshot-related updates for both the first-level item (which is in COMMAND mode) and any second-level 
 items (which are in MERGE mode) are qualified with this flag.
 @return YES if the current update event belongs to the item snapshot; NO otherwise.
 */
@property (nonatomic, readonly, getter=isSnapshot) BOOL snapshot;

/**
 @brief Inquiry method that asks whether the value for a field has changed after the reception of the last update from the Server for an item.
 <br/> If the Subscription mode is COMMAND then the change is meant as relative to the same key.
 @param fieldPos The 1-based position of the field within the "Field List" or "Field Schema".
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the specified field is not part of the LSSubscription.
 @return Unless the Subscription mode is COMMAND, the return value is YES in the following cases: <ul> 
 <li>It is the first update for the item;</li> 
 <li>the new field value is different than the previous field value received for the item.</li> 
 </ul> 
 <br/> If the Subscription mode is COMMAND, the return value is YES in the following cases: <ul>
 <li>it is the first update for the involved key value (i.e. the event carries an "ADD" command);</li> 
 <li>the new field value is different than the previous field value received for the item, relative to the same key value (the event must carry 
 an "UPDATE" command);</li> 
 <li>the event carries a "DELETE" command (this applies to all fields other than the field used to carry key information).</li> 
 </ul> 
 <br/> In all other cases, the return value is NO, including if LSLightstreamerClient#limitExceptionsUse is YES and the specified field is not part of the LSSubscription.
 */
- (BOOL) isValueChangedWithFieldPos:(NSUInteger)fieldPos;

/**
 @brief Inquiry method that asks whether the value for a field has changed after the reception of the last update from the Server for an item.
 <br/> If the Subscription mode is COMMAND then the change is meant as relative to the same key.
 @param fieldName The field name as specified within the "Field List".
 @throws NSException if LSLightstreamerClient#limitExceptionsUse is NO and the specified field is not part of the LSSubscription.
 @return Unless the Subscription mode is COMMAND, the return value is YES in the following cases: <ul>
 <li>It is the first update for the item;</li> 
 <li>the new field value is different than the previous field value received for the item.</li> 
 </ul> 
 <br/> If the Subscription mode is COMMAND, the return value is YES in the following cases: <ul>
 <li>it is the first update for the involved key value (i.e. the event carries an "ADD" command);</li> 
 <li>the new field value is different than the previous field value received for the item, relative to the same key value (the event must carry 
 an "UPDATE" command);</li> 
 <li>the event carries a "DELETE" command (this applies to all fields other than the field used to carry key information).</li> 
 </ul> 
 <br/> In all other cases, the return value is NO, including if LSLightstreamerClient#limitExceptionsUse is YES and the specified field is not part of the LSSubscription.
 */
- (BOOL) isValueChangedWithFieldName:(nonnull NSString *)fieldName;


@end
