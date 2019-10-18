//
//  LSLoggerProvider.h
//  Lightstreamer client for iOS UCA
//

#import <Foundation/Foundation.h>


@protocol LSLogger;


/**
 @brief Simple interface to be implemented to provide custom log consumers to the library.
 <br/> An instance of the custom implemented class has to be passed to the library through the LSLightstreamerClient#setLoggerProvider:.
 */
@protocol LSLoggerProvider <NSObject>


/**
 @brief Request for a Logger instance that will be used for logging occuring on the given category.
 <br/> It is suggested, but not mandatory, that subsequent calls to this method related to the same category return the same Logger instance.
 @param category the log category all messages passed to the given LSLogger instance will pertain to.
 @return An LSLogger instance that will receive log lines related to the given category.
 */
- (nullable id <LSLogger>) loggerWithCategory:(nullable NSString *)category;


@end

