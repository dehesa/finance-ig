//
//  LSConsoleLogger.h
//  Lightstreamer client for iOS UCA
//

#import <Foundation/Foundation.h>

#import "LSConsoleLoggerProvider.h"
#import "LSLogger.h"


/**
 @brief Concrete logger class to provide logging on the system console.
 <br/> Instances of this classes are obtained by the library through the LSLoggerProvider instance set on LSLightstreamerClient#setLoggerProvider:.
 */
@interface LSConsoleLogger : NSObject <LSLogger>


/**
 @brief Creates an instace of the concrete system console logger.
 @param level the desired logging level for this LSConsoleLogger instance.
 @param category the log category all messages passed to the given LSConsoleLogger instance will pertain to.
 */
- (nonnull instancetype) initWithLevel:(LSConsoleLogLevel)level category:(nullable NSString *)category;


@end
