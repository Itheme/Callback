//
//  Callback.m
//  EventGridManager
//
//  Created by Danila Parkhomenko on 27/05/16.
//  Copyright © 2016 Entech Solutions. All rights reserved.
//

#import "Callback.h"

@interface Callback ()

@property (nonatomic, assign) BOOL validInstance;
@property (nonatomic, assign) BOOL executed;

@end

@implementation Callback

- (id)init {
    if (self = [super init]) {
        self.shouldRunOnce = YES;
        self.validInstance = YES;
        self.userInfo = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id)initWithSuccess:(void(^)(void)) successBlock error:(void(^)(void)) errorBlock finalization:(void(^)(void)) finalizationBlock
{
    if (self = [self init]) {
        self.successBlock = successBlock;
        self.errorBlock = errorBlock;
        self.finalizationBlock = finalizationBlock;
    }
    return self;
}

- (id)initWithSuccessWithParam:(void(^)(id result)) successBlockWithParam
                errorWithParam:(void(^)(id error)) errorBlockWithParam
                  finalization:(void(^)(void)) finalizationBlock
{
    if (self = [self init]) {
        self.successBlockWithParam = successBlockWithParam;
        self.errorBlockWithError = errorBlockWithParam;
        self.finalizationBlock = finalizationBlock;
    }
    return self;
}

- (id)initWithTarget:(id)target success:(SEL)success error:(SEL) error finalization:(SEL) finalization
{
    if (self = [self init]) {
        self.target = target;
        self.successMethod = success;
        self.errorMethod = error;
        self.finalizationMethod = finalization;
    }
    return self;
}

- (void)invalidate
{
    self.validInstance = NO;
    [self.next invalidate];
}

- (BOOL)isValid {
    if (self.validInstance) {
        return !self.shouldRunOnce || !self.executed;
    }
    return NO;
}

- (BOOL)isSequenceValid {
    return [self isValid] || [self.next isSequenceValid];
}

- (void)targetPerformSelector:(SEL)selector withParameter:(id)parameter
{
    if ((self.target == nil) || (selector == nil)) return;
    IMP imp = [self.target methodForSelector:self.successMethod];
    NSMethodSignature *signature = [[self.target class] instanceMethodSignatureForSelector:self.successMethod];
    assert(signature.numberOfArguments == 1);
    void (*func)(id, SEL, id) = (void *)imp;
    func(self.target, self.successMethod, parameter);
}

- (void)targetPerformSimpleSelector:(SEL)selector
{
    if ((self.target == nil) || (selector == nil)) return;
    IMP imp = [self.target methodForSelector:self.successMethod];
    NSMethodSignature *signature = [[self.target class] instanceMethodSignatureForSelector:self.successMethod];
    assert(signature.numberOfArguments == 0);
    void (*func)(id, SEL) = (void *)imp;
    func(self.target, self.successMethod);
}

- (void)run:(BOOL)success
{
    if ([self isValid]) {
        if (success) {
            if (self.successBlock) {
                self.successBlock();
            }
            assert(self.successBlockWithParam == nil);
            [self targetPerformSimpleSelector:self.successMethod];
        } else {
            if (self.errorBlock) {
                self.errorBlock();
            }
            if (self.errorBlockWithError) {
                self.errorBlockWithError(nil);
            }
            [self targetPerformSimpleSelector:self.errorMethod];
        }
        if (self.finalizationBlock) {
            self.finalizationBlock();
        }
        self.executed = YES;
        [self targetPerformSimpleSelector:self.finalizationMethod];
    }
    [self.next run:YES];
}

- (void)runWithResult:(id)result success:(BOOL)success
{
    id resultRef = result;
    if ([self isValid]) {
        id validationError = nil;
        result = [self validateResult:result error:nil validationError:&validationError];
        if (success && !validationError) {
            if (self.successBlock) {
                self.successBlock();
            }
            if (self.successBlockWithParam) {
                self.successBlockWithParam(result);
            }
            [self targetPerformSelector:self.successMethod withParameter:result];
        } else {
            if (self.errorBlock) {
                self.errorBlock();
            }
            if (self.errorBlockWithError) {
                self.errorBlockWithError(validationError);
            }
            [self targetPerformSelector:self.errorMethod withParameter:validationError];
        }
        if (self.finalizationBlock) {
            self.finalizationBlock();
        }
        self.executed = YES;
        [self targetPerformSelector:self.finalizationMethod withParameter:validationError?validationError:result];
    }
    [self.next runWithResult:resultRef success:success];
}

- (id)validateResult:(id)result error:(id)error validationError:(id *)validationError {
    if (*validationError == nil) {
        *validationError = error;
    }
    return result;
}

- (void)runWithResult:(id)result error:(id)error success:(BOOL)success
{
    if ([self isValid]) {
        id validationError = nil;
        result = [self validateResult:result error:error validationError:&validationError];
        if (success) {
            if (self.successBlock) {
                self.successBlock();
            }
            if (self.successBlockWithParam) {
                self.successBlockWithParam(result);
            }
            [self targetPerformSelector:self.successMethod withParameter:result];
        } else {
            if (self.errorBlock) {
                self.errorBlock();
            }
            if (self.errorBlockWithError) {
                self.errorBlockWithError(validationError);
            }
            [self targetPerformSelector:self.errorMethod withParameter:validationError];
        }
        if (self.finalizationBlock) {
            self.finalizationBlock();
        }
        self.executed = YES;
        [self targetPerformSelector:self.finalizationMethod withParameter:validationError?validationError:result];
    }
    [self.next runWithResult:result error:error success:success];
}

- (void)runWithError:(id)error
{
    [self runWithResult:nil error:error success:NO];
}

- (void)addNextObject:(Callback *)object
{
    if ([self.next isEqual:self]) return;
    if (self.next) {
        [self.next addNextObject:object];
    } else {
        self.next = object;
    }
}

@end

@implementation JSONCallback

- (id)validateResult:(id)result error:(id)error validationError:(id *)validationError {
    if (error) {
        if (self.failureObjectName) {
            *validationError = [error objectForKey:self.failureObjectName];
        } else {
            *validationError = error;
        }
    } else {
        if (self.successObjectName) {
            if (result) {
                for (NSString *param in self.userInfoObjectNames) {
                    id value = result[param];
                    if (value) {
                        self.userInfo[param] = value;
                    }
                }
                return [result objectForKey:self.successObjectName];
            }
        }
    }
    return [super validateResult:result error:error validationError:validationError];
}

- (void)cancel
{
    if ([self isValid]) {
        if (self.finalizationBlock) {
            self.finalizationBlock();
        }
        [self targetPerformSelector:self.finalizationMethod withParameter:nil];
    }
    [self.sessionDataTask cancel];
    if ([self.next isKindOfClass:[JSONCallback class]]) {
        [((JSONCallback *)self.next) cancel];
    }
    [self invalidate];
}

- (BOOL)showErrorAlert {
    return _showErrorAlert && [self isValid];
}

- (void)runWithResult:(id)result error:(id)error success:(BOOL)success {
    [super runWithResult:result error:error success:success];
    self.viewControllerForAlerts = nil;
}

- (void)invalidate {
    [super invalidate];
    self.viewControllerForAlerts = nil;
}

@end
