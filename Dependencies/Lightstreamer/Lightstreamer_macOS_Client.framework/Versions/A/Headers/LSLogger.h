//
//  LSLogger.h
//  Lightstreamer client for iOS UCA
//

#import <Foundation/Foundation.h>


/**
 @brief Interface to be implemented to consume log from the library.
 <br/> Instances of implemented classes are obtained by the library through the LSLoggerProvider instance set on LSLightstreamerClient#setLoggerProvider:.
 */
@protocol LSLogger <NSObject>


/**
 @brief Receives log messages at Error level.
 @param line The message to be logged.
 */
- (void) error:(nonnull NSString *)line;

/**
 @brief Receives log messages at Error level and a related exception.
 @param line The message to be logged.
 @param exception An Exception instance related to the current log message.
 */
- (void) error:(nonnull NSString *)line withException:(nonnull NSException *)exception;

/**
 @brief Receives log messages at Warn level.
 @param line The message to be logged.
 */
- (void) warn:(nonnull NSString *)line;

/**
 @brief Receives log messages at Warn level and a related exception.
 @param line The message to be logged.
 @param exception An Exception instance related to the current log message.
 */
- (void) warn:(nonnull NSString *)line withException:(nonnull NSException *)exception;

/**
 @brief Receives log messages at Info level.
 @param line The message to be logged.
 */
- (void) info:(nonnull NSString *)line;

/**
 @brief Receives log messages at Info level and a related exception.
 @param line The message to be logged.
 @param exception An Exception instance related to the current log message.
 */
- (void) info:(nonnull NSString *)line withException:(nonnull NSException *)exception;

/**
 @brief Receives log messages at Debug level.
 @param line The message to be logged.
 */
- (void) debug:(nonnull NSString *)line;

/**
 @brief Receives log messages at Debug level and a related exception.
 @param line The message to be logged.
 @param exception An Exception instance related to the current log message.
 */
- (void) debug:(nonnull NSString *)line withException:(nonnull NSException *)exception;

/**
 @brief Receives log messages at Fatal level.
 @param line The message to be logged.
 */
- (void) fatal:(nonnull NSString *)line;

/**
 @brief Receives log messages at Fatal level and a related exception.
 @param line The message to be logged.
 @param exception An Exception instance related to the current log message.
 */
- (void) fatal:(nonnull NSString *)line withException:(nonnull NSException *)exception;

/**
 @brief Checks if this logger is enabled for the Debug level.
 <br/> The property should be true if this logger is enabled for Debug events, false otherwise.
 <br/> This property is intended to lessen the computational cost of disabled log Debug statements. Note that even if the property is false, Debug log lines
 may be received anyway by the Debug methods.
 */
@property (nonatomic, readonly, getter=isDebugEnabled) BOOL debugEnabled;

/**
 @brief Checks if this logger is enabled for the Info level.
 <br/> The property should be true if this logger is enabled for Info events, false otherwise.
 <br/> This property is intended to lessen the computational cost of disabled log Info statements. Note that even if the property is false, Info log lines
 may be received anyway by the Info methods.
 */
@property (nonatomic, readonly, getter=isInfoEnabled) BOOL infoEnabled;

/**
 @brief Checks if this logger is enabled for the Warn level.
 <br/> The property should be true if this logger is enabled for Warn events, false otherwise.
 <br/> This property is intended to lessen the computational cost of disabled log Warn statements. Note that even if the property is false, Warn log lines
 may be received anyway by the Warn methods.
 */
@property (nonatomic, readonly, getter=isWarnEnabled) BOOL warnEnabled;

/**
 @brief Checks if this logger is enabled for the Error level.
 <br/> The property should be true if this logger is enabled for Error events, false otherwise.
 <br/> This property is intended to lessen the computational cost of disabled log Error statements. Note that even if the property is false, Error log lines
 may be received anyway by the Error methods.
 */
@property (nonatomic, readonly, getter=isErrorEnabled) BOOL errorEnabled;

/**
 @brief Checks if this logger is enabled for the Fatal level.
 <br/> The property should be true if this logger is enabled for Fatal events, false otherwise.
 <br/> This property is intended to lessen the computational cost of disabled log Fatal statements. Note that even if the property is false, Fatal log lines
 may be received anyway by the Fatal methods.
 */
@property (nonatomic, readonly, getter=isFatalEnabled) BOOL fatalEnabled;


@end
