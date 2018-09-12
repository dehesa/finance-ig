//
//  LSConsoleLoggerProvider.h
//  Lightstreamer client for iOS UCA
//

#import <Foundation/Foundation.h>

#import "LSLoggerProvider.h"


typedef NS_ENUM(NSInteger, LSConsoleLogLevel) {
	LSConsoleLogLevelDebug= 0,
	LSConsoleLogLevelInfo= 10,
	LSConsoleLogLevelWarn= 25,
	LSConsoleLogLevelError= 50,
	LSConsoleLogLevelFatal= 100
};


/**
 @brief Simple concrete logging provider that logs on the system console.
 <br/> To be used, an instance of this class has to be passed to the library through the LSLightstreamerClient#setLoggerProvider:.
 */
@interface LSConsoleLoggerProvider : NSObject <LSLoggerProvider>


/**
 @brief Creates an instace of the concrete system console logger.
 @param level the desired logging level for this LSConsoleLoggerProvider instance.
 */
- (nonnull instancetype) initWithLevel:(LSConsoleLogLevel)level;


@end
