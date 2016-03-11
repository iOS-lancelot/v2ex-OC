//
//  WTTopicViewModel.h
//  v2ex
//
//  Created by 无头骑士 GJ on 16/3/12.
//  Copyright © 2016年 无头骑士 GJ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WTTopicNew.h"
@interface WTTopicViewModel : NSObject
/** 话题模型 */
@property (nonatomic, strong) WTTopicNew    *topic;
/** 话题的详情Url */
@property (nonatomic, strong) NSString      *topicDetailUrl;
/** 头像 */
@property (nonatomic, strong) NSURL         *iconURL;

/**
 *  根据data解析出话题数组
 *
 *  @param data data
 *
 *  @return 话题数组
 */
+ (NSMutableArray *)topicsWithData:(NSData *)data;

/**
 *  是否是 `最近`节点
 *
 *  @param urlSuffix url后缀
 *
 *  @return YES 是 NO 否
 */
+ (BOOL)isNeedNextPage:(NSString *)urlSuffix;

@end
