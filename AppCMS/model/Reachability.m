//
//  Reachability.m
//  FilePorter
//
//  Created by 長島 伸光 on 11/02/24.
//

#import "Reachability.h"

//リーチャビリティ用通知オブジェクト
#define NETWORK_REACH_NOTIFICATION @"NetworkReachNotification@@"

@implementation Reachability

static void networkReachCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    [[NSNotificationCenter defaultCenter] postNotificationName:NETWORK_REACH_NOTIFICATION object:nil];
//    [Logger logDebug:@"POST NETWORK_REACH_NOTIFICATION"];
}

static Reachability *reachability = nil;

+ (id)buildObject 
{
    static dispatch_once_t once;
    dispatch_once( &once, ^{
        reachability = [[self alloc] init];
    });
	return reachability;
}

+ (id)allocWithZone:(NSZone *)zone 
{
    __block id ret = nil;
    
    static dispatch_once_t once;
    dispatch_once( &once, ^{
        reachability = [super allocWithZone:zone];
        [reachability setup];
        ret = reachability;
    });
    
    return  ret;
}

- (id)copyWithZone:(NSZone *)zone 
{
	return self;
}

- (void)dealloc
{
    if(!delegatorList_) {
        [delegatorList_ removeAllObjects];
        delegatorList_ = nil;
    }
}

- (void)setup 
{
    if(!delegatorList_) {
        delegatorList_ = [[NSMutableArray alloc] initWithCapacity:0];
    }
}

- (void)setDelegate:(id<ReachabilityDelegate>)delegator 
{
    if(![delegatorList_ containsObject:delegator]) {
        [delegatorList_ addObject:delegator];
    }
	[self watchNetwork];
}

- (void)removeDelegate:(id<ReachabilityDelegate>)delegator 
{
    [delegatorList_ removeObject:delegator];
}

- (void)reachNetwork:(NSNotification *)note 
{
	SCNetworkReachabilityUnscheduleFromRunLoop(reachabilityRef_, [[NSRunLoop mainRunLoop] getCFRunLoop], kCFRunLoopDefaultMode);
	CFRelease(reachabilityRef_);
	reachabilityRef_ = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NETWORK_REACH_NOTIFICATION object:nil];
	
    if(delegatorList_) {
        for(id<ReachabilityDelegate> delegator in delegatorList_) {
            [delegator reachNetwork];
        }
        delegatorList_ = [[NSMutableArray alloc] initWithCapacity:0];
    }
}

- (void)watchNetwork 
{
    if(!reachabilityRef_) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachNetwork:) name:NETWORK_REACH_NOTIFICATION object:nil];
        reachabilityRef_ =  SCNetworkReachabilityCreateWithName(NULL, REACHABLE_CHECK_HOSTNAME);
        SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
        SCNetworkReachabilitySetCallback(reachabilityRef_, networkReachCallback, &context);
        SCNetworkReachabilityScheduleWithRunLoop(reachabilityRef_, [[NSRunLoop mainRunLoop] getCFRunLoop], kCFRunLoopDefaultMode);
	}
}

- (BOOL)waitReachable 
{
    if(delegatorList_ && [delegatorList_ count] > 0) 
    {
		return YES;
	}
	return NO;
}

@end
