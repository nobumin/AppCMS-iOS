//
//  Reachability.h
//  FilePorter
//
//  Created by 長島 伸光 on 11/02/24.
//  Copyright 2013 Sony Corporation
//

#import <SystemConfiguration/SCNetworkReachability.h>
#import <Foundation/Foundation.h>

#define REACHABLE_CHECK_HOSTNAME "google.com"
#define ACCESSABLE_CHECK_URL @"http://google.com"

@protocol ReachabilityDelegate

@optional
- (void)reachNetwork;

@end

@interface Reachability : NSObject {
	SCNetworkReachabilityRef reachabilityRef_;
    NSMutableArray *delegatorList_;
}

+ (id)buildObject;
- (void)setup;
- (void)setDelegate:(id<ReachabilityDelegate>)delegator;
- (void)removeDelegate:(id<ReachabilityDelegate>)delegator;
- (void)watchNetwork;
- (BOOL)waitReachable;

@end
