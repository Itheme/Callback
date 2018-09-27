//
//  Callback.h
//  EventGridManager
//
//  Created by Danila Parkhomenko on 27/05/16.
//  Copyright © 2016 Entech Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    CachabilityNone = 0,
    CachabilityEtag = 1,
    CachabilitySmart = 2,
} Cachability;

@interface Callback <__covariant ObjectType> : NSObject

@property (nonatomic, copy) void(^successBlock)(void);
@property (nonatomic, copy) void(^successBlockWithParam)(ObjectType result);
@property (nonatomic, copy) void(^errorBlock)(void);
@property (nonatomic, copy) void(^errorBlockWithError)(ObjectType error);
@property (nonatomic, copy) void(^finalizationBlock)(void);
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL successMethod;
@property (nonatomic, assign) SEL errorMethod;
@property (nonatomic, assign) SEL finalizationMethod;
@property (nonatomic, assign) BOOL shouldRunOnce;
@property (nonatomic, assign, readonly) BOOL executed;
@property (nonatomic, strong) NSMutableDictionary *userInfo;
@property (nonatomic, strong) Callback *next;

- (BOOL)isValid;
- (BOOL)isSequenceValid;

- (id)initWithSuccess:(void(^)(void)) successBlock error:(void(^)(void)) errorBlock finalization:(void(^)(void)) finalizationBlock;
- (id)initWithSuccessWithParam:(void(^)(ObjectType result)) successBlockWithParam
                errorWithParam:(void(^)(ObjectType error)) errorBlockWithParam
                  finalization:(void(^)(void)) finalizationBlock;
- (id)initWithTarget:(id)target success:(SEL)success error:(SEL) error finalization:(SEL) finalization;
- (void)invalidate;
- (void)run:(BOOL)success;
- (void)runWithResult:(ObjectType)result success:(BOOL)success;
- (void)runWithResult:(ObjectType)result error:(ObjectType)error success:(BOOL)success;
- (void)runWithError:(ObjectType)error;
- (void)addNextObject:(Callback *)object;

@end

@class JSONCallback;

@protocol CallbackDelegate <NSObject>

- (void)willCancel:(JSONCallback *)sender;

@end

@interface JSONCallback <ObjectType>: Callback

@property (nonatomic, strong) NSURLSessionDataTask *sessionDataTask;
@property (nonatomic, strong) NSString *successObjectName;
@property (nonatomic, strong) NSArray <NSString *> *userInfoObjectNames;
@property (nonatomic, strong) NSString *failureObjectName;
@property (nonatomic, weak) id<CallbackDelegate> delegate;
@property (nonatomic, strong) UIViewController *viewControllerForAlerts;
@property (nonatomic, assign) BOOL showErrorAlert;
@property (nonatomic, assign) Cachability cachable;

- (void)cancel;

@end
