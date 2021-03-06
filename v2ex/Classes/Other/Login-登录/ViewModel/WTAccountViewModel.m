//
//  WTAccountViewModel.m
//  v2ex
//
//  Created by 无头骑士 GJ on 16/3/16.
//  Copyright © 2016年 无头骑士 GJ. All rights reserved.
//

#import "WTAccountViewModel.h"
#import "TFHpple.h"
#import "NetworkTool.h"
#import "MisakaNetworkTool.h"
#import "WTURLConst.h"
#import "WTLoginRequestItem.h"
#import "MJExtension.h"
#import "WTAppDelegateTool.h"
#import "WTRegisterReqItem.h"
#import "NSString+YYAdd.h"

#define WTFilePath [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent: @"account.plist"]

NSString * const WTUsernameOrEmailKey = @"WTUsernameOrEmailKey";

NSString * const WTPasswordKey = @"WTPasswordKey";

@implementation WTAccountViewModel

static WTAccountViewModel *_instance;

+ (instancetype)shareInstance
{
    return [[self alloc] init];
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone: zone];
        
        _instance.account = [WTAccount new];
        _instance.userItem = [WTUserItem new];
        _instance.account.usernameOrEmail = [[NSUserDefaults standardUserDefaults] objectForKey: WTUsernameOrEmailKey];
        _instance.account.password = [[NSUserDefaults standardUserDefaults] objectForKey: WTPasswordKey];

    });
    return _instance;
}

/**
 *  自动登陆
 */
- (void)autoLogin
{
    if (self.isLogin)
    {
        NSString *username = self.account.usernameOrEmail;
        NSString *password = self.account.password;

        [[WTAccountViewModel shareInstance] getOnceWithUsername: username password: password success:^{
            
        } failure:^(NSError *error) {
            
        }];
    }
}

/**
 *  是否登陆过
 *
 */
- (BOOL)isLogin
{
    return [WTAccountViewModel shareInstance].account.usernameOrEmail.length > 0;
}

/**
 *  是否登陆过
 *
 */
- (BOOL)isMasakaLogin
{
    return [WTAccountViewModel shareInstance].userItem.uid > 0;
}

/**
 *  退出登陆
 */
- (void)loginOut
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey: WTUsernameOrEmailKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey: WTPasswordKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    self.account.usernameOrEmail = nil;
    self.account.password = nil;
    self.userItem = nil;
    
    // 1、切换帐号有缓存问题
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [storage cookies])
    {
        [storage deleteCookie:cookie];
    }
}

- (void)saveUsernameAndPassword
{
    [[NSUserDefaults standardUserDefaults] setObject: self.account.usernameOrEmail forKey: WTUsernameOrEmailKey];
    [[NSUserDefaults standardUserDefaults] setObject: self.account.password forKey: WTPasswordKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/**
 *  登陆
 *
 *  @param username 用户名
 *  @param password 密码
 *  @param success  请求成功的回调
 *  @param failure  请求失败的回调
 */
- (void)getOnceWithUsername:(NSString *)username password:(NSString *)password success:(void (^)())success failure:(void (^)(NSError *error))failure
{
    void (^errorBlock)(NSError *error) = ^(NSError *error){
        if (failure)
        {
            failure(error);
        }
    };
    
    
//    // 1、切换帐号有缓存问题
//    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
//    for (NSHTTPCookie *cookie in [storage cookies])
//    {
//        [storage deleteCookie:cookie];
//    }
    
    // 2、获取网页中once的值
    NSString *urlString = [WTHTTPBaseUrl stringByAppendingPathComponent: WTLoginUrl];
    [[NetworkTool shareInstance] requestWithMethod: HTTPMethodTypeGET url: urlString param: nil success:^(id responseObject) {
        
        // 2.1、获取表单中请求参数的key和value
        WTLoginRequestItem *loginRequestItem = [WTAccountViewModel getLoginRequestParamWithData: responseObject];
        
        if (loginRequestItem == nil)
        {
            WTLog(@"loginRequestItem获取不到")
            return;
        }
        
        // 2.2、登录
        [[WTAccountViewModel shareInstance] loginWithUrlString: urlString loginRequestItem: loginRequestItem username:username password: password success:^{
            if (success)
            {
                success();
            }
        } failure: errorBlock];
       
    } failure: errorBlock];
}

/**
 *  签到
 *
 */
- (void)pastWithSuccess:(void(^)())success failure:(void(^)(NSError *error))failure
{
    NSString *url = [WTHTTPBaseUrl stringByAppendingPathComponent: self.account.pastUrl];
    
    [[NetworkTool shareInstance] GETWithUrlString: url success:^(id data) {
        
        NSString *html = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        
        if ([html containsString: @"查看我的账户余额"])
        {
            if (success)
            {
                success();
            }
            
            self.account.pastUrl = nil;
            return;
        }
        
        if (failure)
        {
            failure([[NSError alloc] initWithDomain: WTDomain code: WTErrorCode userInfo: @{WTErrorMessageKey: @"其他错误"}]);
        }
        
    } failure:^(NSError *error) {
        
        if (failure)
        {
            failure(error);
        }
        
    }];
}

/**
 *  登录
 *
 *  @param urlString        url
 *  @param loginRequestItem 请求参数key和value
 *  @param username         username的值
 *  @param password         password的值
 *  @param success          请求成功的回调
 *  @param failure          请求失败的回调
 */
- (void)loginWithUrlString:(NSString *)urlString loginRequestItem:(WTLoginRequestItem *)loginRequestItem username:(NSString *)username password:(NSString *)password success:(void (^)())success failure:(void (^)(NSError *error))failure
{
    // 1、请求参数
    NSDictionary *param = [loginRequestItem getLoginRequestParam: username passwordValue: password];
    
    [[NetworkTool shareInstance] requestFirefoxWithMethod: HTTPMethodTypePOST url: urlString param: param success:^(id responseObject) {
        
        NSString *html = [[NSString alloc] initWithData: responseObject encoding: NSUTF8StringEncoding];
        

        
        // 判断是否登陆成功
        if ([html containsString: @"notifications"])        // 登陆成功
        {
            WTLog(@"登陆成功")
            [NSKeyedArchiver archiveRootObject: self.account toFile: WTFilePath];
            
            // 是否已经领取过奖励
            if ([html containsString: @"领取今日的登录奖励"])
            {
                
            }
            
            // 登陆成功获取用户的信息
            [self getUserInfoWithResponseObject: responseObject param: param loginRequestItem: loginRequestItem success: success failure: failure];
            
            
            return;
        }
        
        NSError *error = nil;
        if([html containsString: @"用户名和密码无法匹配"])
        {
            error = [NSError errorWithDomain: WTDomain code: -1011 userInfo: @{@"message" : @"用户名和密码无法匹配"}];
            WTLog(@"用户名和密码无法匹配")
        }
        else
        {
            WTLog(@"登陆未知错误")
            WTLog(@"html:%@", [[NSString alloc] initWithData: responseObject encoding: NSUTF8StringEncoding])
            error = [NSError errorWithDomain: WTDomain code: -1011 userInfo: @{@"message" : @"未知错误"}];
        }
        
        if (failure)
        {
            failure(error);
        }
        
    } failure:^(NSError *error) {
        if (error)
        {
            failure(error);
        }
    }];
}


/**
 获取用户的详细信息

 @param responseObject   responseObject
 @param param            请求参数
 @param loginRequestItem 请求参数
 @param success          请求成功的回调
 @param failure          请求失败的回调
 */
- (void)getUserInfoWithResponseObject:(NSData *)responseObject param:(NSDictionary *)param loginRequestItem:(WTLoginRequestItem *)loginRequestItem success:(void (^)())success failure:(void (^)(NSError *error))failure
{
    // 获取签到的网址
    [[NetworkTool shareInstance] GETWithUrlString: @"https://www.v2ex.com/mission/daily" success:^(id data) {
        self.account = [self getUserInfoWithData: responseObject usernameOrEmail: param[loginRequestItem.usernameKey] password: param[loginRequestItem.passwordKey]];
        
        [self saveUsernameAndPassword];
        self.account.pastUrl = [self getPastStateWithData: data];
        
        // 登陆misaka14服务器
        WTUserItem *userItem = [WTUserItem new];
        userItem.avatarUrl = [self.account.avatarURL absoluteString];
        userItem.username = self.account.usernameOrEmail;
#if Test == 0
        [self loginToMisaka14WithUserItem: userItem success:^(WTUserItem *loginUserItem) {
            
            self.userItem = loginUserItem;
            
            
        } failure:^(NSError *error) {
            
        }];
#else
        
#endif
        
        
        
        if (success)
        {
            success();
        }
        
    } failure:^(NSError *error) {
        if (error)
        {
            failure(error);
        }
    }];
}


/**
 *  获取注册的请求参数
 *
 *  @param success 请求成功的回调
 *  @param failure 请求失败的回调
 */
- (void)getRegisterReqItemWithSuccess:(void (^)(WTRegisterReqItem *item))success failure:(void (^)(NSError *error))failure
{
    NSString *url = [WTHTTPBaseUrl stringByAppendingPathComponent: WTRegisterUrl];
    
    [[NetworkTool shareInstance] requestWithMethod: HTTPMethodTypeGET url: url param: nil success:^(id responseObject) {
       
        WTRegisterReqItem *item = [self getRegisterReqItemWithData: responseObject];
        if (item.verificationCode != nil)
        {
            if (success)
            {
                success(item);
                return;
            }
        }
        
        if (failure)
        {
            failure([[NSError alloc] initWithDomain: @"com.wutouqishi" code: -1011 userInfo: @{@"errorInfo" : @"获取验证码Url失败"}]);
        }
        
    } failure:^(NSError *error) {
        if (failure)
        {
            failure(error);
        }
    }];
}

/**
 *  注册
 *
 *  @param item     注册请求参数
 *  @param success  请求成功的回调
 *  @param failure  请求失败的回调
 */
- (void)registerWithRegisterReqItem:(WTRegisterReqItem *)item success:(void (^)(BOOL isSuccess))success failure:(void(^)(NSError *error))failure
{
    // 1、拼接参数
    NSDictionary *param = @{
                            item.usernameKey : item.usernameValue,
                            item.passwordKey : item.passwordValue,
                            item.emailKey : item.emailValue,
                            item.verificationCodeKey : item.verificationCodeValue,
                            item.onceKey : item.onceValue
                            };
    
    NSString *url = [WTHTTPBaseUrl stringByAppendingPathComponent: WTRegisterUrl];

    [[NetworkTool shareInstance] requestWithMethod: HTTPMethodTypePOST url: url param: param success:^(id responseObject) {
        
        NSString *html = [[NSString alloc] initWithData: responseObject encoding: NSUTF8StringEncoding];
        
        if ([html containsString: @"账户余额"]) // 注册成功
        {
            if (success)
            {
                success(YES);
            }
            return;
        }
        
        NSError *error = nil;
        if ([html containsString: @"注册过程中遇到一些问题："])
        {
            if ([html containsString: @"电子邮件地址"])
            {
                error = [[NSError alloc] initWithDomain: WTDomain code: -1011 userInfo: @{@"errorInfo" : @"该邮箱已被注册过"}];
            }
            else if([html containsString: @"输入的验证码不正确"])
            {
                error = [[NSError alloc] initWithDomain: WTDomain code: -1011 userInfo: @{@"errorInfo" : @"输入的验证码不正确"}];
            }
            else if([html containsString: @"用户名"])
            {
                error = [[NSError alloc] initWithDomain: WTDomain code: -1011 userInfo: @{@"errorInfo" : @"用户名已经被注册过"}];
            }
        }
        
        if (failure)
        {
            failure(error);
        }
        
    } failure:^(NSError *error) {
        WTLog(@"registerWithUrlString Error:%@", error)
        if (failure)
        {
            failure(error);
        }
    }];
}

#pragma mark - 根据二进制的值获取用户登录请求的必备参数的Key、Value
+ (WTLoginRequestItem *)getLoginRequestParamWithData:(NSData *)data
{
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData: data];
    
    NSString *once = [[doc peekAtSearchWithXPathQuery: @"//input[@name='once']"] objectForKey: @"value"];
    NSArray *slArray = [doc searchWithXPathQuery: @"//input[@class='sl']"];
    NSString *usernameKey = [slArray.firstObject objectForKey: @"name"];
    NSString *passwordKey = [slArray.lastObject objectForKey: @"name"];
    
    return [WTLoginRequestItem loginRequestItemWithOnce: once usernameKey: usernameKey passwordKey: passwordKey];
}

#pragma mark - 根据二进制获取请求参数
- (WTRegisterReqItem *)getRegisterReqItemWithData:(NSData *)data
{
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData: data];
    
    NSArray<TFHppleElement *> *trE = [doc searchWithXPathQuery: @"//form[@action='/signup']//table//tr"];
    
    NSArray<TFHppleElement *> *slE = [doc searchWithXPathQuery: @"//input[@class='sl']"];
    
    
    WTRegisterReqItem *item = [WTRegisterReqItem new];
    
    if (trE.count > 3)
    {
        NSArray *imgEs = [trE[3] searchWithXPathQuery: @"//img"];
        item.verificationCode = imgEs.count > 0 ? [imgEs[0] objectForKey: @"src"] : nil;
        if (item.verificationCode != nil)
        {
            item.verificationCode = [WTHTTPBaseUrl stringByAppendingPathComponent: item.verificationCode];
        }
    }
    
    if (slE.count > 3)
    {
        item.usernameKey = [[slE objectAtIndex: 0] objectForKey: @"name"];
        
        item.passwordKey = [[slE objectAtIndex: 1] objectForKey: @"name"];
        
        item.emailKey = [[slE objectAtIndex: 2] objectForKey: @"name"];
        
        item.verificationCodeKey = [[slE objectAtIndex: 3] objectForKey: @"name"];
    }
    
    
    
    return item;
}

/**
 *  获取用户的信息
 *
 *  @param data            二进制
 *  @param usernameOrEmail 用户名
 *  @param password        密码
 *
 *  @return WTAccount
 */
- (WTAccount *)getUserInfoWithData:(NSData *)data usernameOrEmail:(NSString *)usernameOrEmail password:(NSString *)password
{
    //WTLog(@"data:%@", [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding])
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData: data];
    NSArray<TFHppleElement *> *fadeEs = [doc searchWithXPathQuery: @"//div[@id='Rightbar']//span[@class='fade']"];
    NSString *avatar = [[doc peekAtSearchWithXPathQuery: @"//img[@class='avatar']"] objectForKey: @"src"];
    
    WTAccount *account = [WTAccount new];
    account.usernameOrEmail = usernameOrEmail;
    account.password = password;
    
    if(fadeEs.count == 8)
    {
        account.signature = fadeEs.firstObject.content;
    }
//
    account.avatarURL = [NSURL URLWithString: [NSString stringWithFormat: @"%@%@", WTHTTP, avatar]];
    return account;
}

/**
 *  获取领取奖励的Url
 */
- (void)getPastState
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
    });
}

- (NSString *)getPastStateWithData:(NSData *)data
{
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData: data];
    TFHppleElement *inputE = [doc peekAtSearchWithXPathQuery: @"//input[@class='super normal button']"];
    NSString *value = [inputE objectForKey: @"value"];
    if (![value isEqualToString: @"查看我的账户余额"])
    {
        NSString *onclickValue = [inputE objectForKey: @"onclick"];
        return [[onclickValue stringByReplacingOccurrencesOfString: @"location.href = '" withString: @""] stringByReplacingOccurrencesOfString: @"';" withString: @""];
    }
    return nil;
}


/**
 登陆至misaka14
 
 @param success 请求成功的回调
 @param failure 请求失败的回调
 */
- (void)loginToMisaka14WithUserItem:(WTUserItem *)userItem success:(void(^)(WTUserItem *loginUserItem))success failure:(void(^)(NSError *error))failure;
{
    NSString *url = [WTMisaka14Domain stringByAppendingPathComponent: @"user/login"];
    [[MisakaNetworkTool shareInstance] requestWithMethod: MisakaHTTPMethodTypePOST url: url param: userItem.mj_keyValues success:^(id responseObject) {
        
        if ([[responseObject objectForKey: @"code"] integerValue]  == 200)
        {
            WTUserItem *loginUserItem = [WTUserItem mj_objectWithKeyValues: [responseObject objectForKey: @"result"]];
            
            self.userItem = loginUserItem;
            
//            WTAppDelegateTool *appDelegateTool = [WTAppDelegateTool new];
            
            WTLog(@"misaka14服务器登陆成功UserID:%lu", loginUserItem.uid)
            
            // 初始化融云
            [[WTAppDelegateTool shareAppDelegateTool] initRCIM];
            
            if (success)
            {
                success(loginUserItem);
            }
        }
        
        
        
        
    } failure:^(NSError *error) {
        WTLog(@"loginToMisaka14WithSuccess Error:%@", error)
        if (failure)
        {
            failure(error);
        }
    }];
}

/**
 获取用户信息
 
 @param userId  WTUserItem
 @param success 请求成功的回调
 @param failure 请求失败的回调
 */
+ (void)getUserInfoFromMisaka14WithUserItem:(WTUserItem *)userItem success:(void(^)(WTUserItem *userItem))success failure:(void(^)(NSError *error))failure
{
    NSString *url = [WTMisaka14Domain stringByAppendingPathComponent: @"user/userInfo"];
    [[MisakaNetworkTool shareInstance] requestWithMethod: MisakaHTTPMethodTypePOST url: url param: userItem.mj_keyValues success:^(id responseObject) {
        
        if ([[responseObject objectForKey: @"code"] integerValue]  == 200)
        {
            WTUserItem *resultUserItem = [WTUserItem mj_objectWithKeyValues: [responseObject objectForKey: @"result"]];
        
            if (success)
            {
                success(resultUserItem);
            }
        }
        
    } failure:^(NSError *error) {
        WTLog(@"loginToMisaka14WithSuccess Error:%@", error)
        if (failure)
        {
            failure(error);
        }
    }];
}
@end
