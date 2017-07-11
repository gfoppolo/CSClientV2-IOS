//
//  CSClientV2.m
//  ChequeSante
//
//  Created by Richard CEVAER on 28/09/2016.
//  Copyright © 2016 CareLabs. All rights reserved.
//

#import "CSClientV2.h"

@interface CSClientV2 ()
@end


@implementation CSClientV2

+ (CSClientV2*)sharedClient:(NSString*)url {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithBaseURL:[NSURL URLWithString:url]];
    });
    return sharedInstance;
}


#pragma mark - Utils
-(id) initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if(self) {
        NSMutableSet *contentTypes = [[NSMutableSet alloc] initWithSet:self.responseSerializer.acceptableContentTypes];
        [contentTypes addObject:@"text/html"];
        self.responseSerializer.acceptableContentTypes = contentTypes;
    }
    return self;
}

- (NSString*) cacheFilePathWithKey:(NSString*)key {
    NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [docsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"/Caches/%@.json",key]];
}

- (void) cacheJSON:(id)JSON withKey:(NSString*)key {
    NSData * data = [NSJSONSerialization dataWithJSONObject:JSON options:0 error:nil];
    [data writeToFile:[self cacheFilePathWithKey:key] atomically:YES];
}

- (id) getCachedJSONWithKey:(NSString*)key {
    NSData * responseObject = [[NSData alloc] initWithContentsOfFile:[self cacheFilePathWithKey:key]];
    if (responseObject) {
        NSDictionary * JSON = [NSJSONSerialization JSONObjectWithData:responseObject options:0 error:nil];
        return JSON;
    }
    return nil;
}


#pragma mark - Authentification

-(void) authentifyUserWithEmail:(NSString*)email password:(NSString*)password andApiKey:(NSString *)key completion:(void (^)(NSDictionary * data, NSError * error))block {
    [self.requestSerializer setValue:key forHTTPHeaderField:@"cs-api-key"];
    [self.requestSerializer setValue:[[NSLocale currentLocale] localeIdentifier] forHTTPHeaderField:@"Accept-Language"];
    
    NSDictionary * params = @{@"username":email,@"password":password};
    
    [self POST:@"auth/authentification" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSDictionary * response = responseObject[@"data"];

#ifdef DEBUG
                NSLog(@"authentifyUser response%@",response);
#endif

                NSHTTPURLResponse *HttpResponse = ((NSHTTPURLResponse *)[task response]);
                NSDictionary *headers = [HttpResponse allHeaderFields];

                NSString *userId = @"";
                if(headers[@"Token"] !=nil) {
                    NSString *base64TokenString = headers[@"Token"];
                    NSData *decodedTokenData = [[NSData alloc] initWithBase64EncodedString:base64TokenString options:0];
                    NSString *decodedTokenString = [[NSString alloc] initWithData:decodedTokenData encoding:NSUTF8StringEncoding];
                    NSData *data = [decodedTokenString dataUsingEncoding:NSUTF8StringEncoding];
                    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    self.currentToken = json[@"token"];
                    self.currentLimit = json[@"limit"];
                    userId = [NSString stringWithFormat: @"%@", json[@"user_id"]];
                }
#ifdef DEBUG
                NSLog(@"****************** self.currentToken : %@",self.currentToken);
#endif
                
                [[NSUserDefaults standardUserDefaults] setObject:email forKey:@"CurrentUserEmail"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                //Les forHTTPHeaderField sont établis pour tous les appels suivants
                [self.requestSerializer setValue:[NSString stringWithFormat:@"%@", response[@"id"]] forHTTPHeaderField:@"cs-user-id"];
                [self.requestSerializer setValue:self.currentToken forHTTPHeaderField:@"cs-token"];
                
                if(block) ((void (^)()) block)(response,nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil, error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil, error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"authentifyUserWithEmail error : %@", error);
        NSError * err;
        NSHTTPURLResponse *response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
        NSInteger statusCode = response.statusCode;
        if (statusCode == 404) {
            err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:404 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"L'email est inconnu", nil)}];
        }
        else if (statusCode == 401) {
            err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:0 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nemail ou mot de passe invalide.", nil)}];
        }
        else if (statusCode == 0) {
            err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:0 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        }
        else if (statusCode > 0) {
            err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:statusCode userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:NSLocalizedString(@"Erreur code : %ld\n%@", nil), statusCode, error.userInfo[@"NSLocalizedDescription"]]}];
        }
        
        if(block) ((void (^)()) block)(nil, err);
    }];
}


- (void) logout {
    self.currentToken = nil;
    self.currentLimit = nil;
}


- (void) reinitializePasswordForEmail:(NSString*)email andApiKey:(NSString *)key completion:(void (^)(NSError * error))block {
    [self.requestSerializer setValue:key forHTTPHeaderField:@"cs-api-key"];
    [self.requestSerializer setValue:[[NSLocale currentLocale] localeIdentifier] forHTTPHeaderField:@"Accept-Language"];
    [self POST:@"auth/forgotpassword" parameters:@{@"username":email} success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"reinitializePasswordForEmail error : %@", error);
        NSError * err;
        NSHTTPURLResponse *response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
        NSInteger statusCode = response.statusCode;
        if (statusCode == 404) {
            err = [[NSError alloc] initWithDomain:NSLocalizedString(@"chequesante.com", nil) code:404 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"L'email est inconnu", nil)}];
        }
        else if (statusCode == 0) {
            err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        }
        else if (statusCode > 0) {
            err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:statusCode userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Error code : %ld\n%@", (long)statusCode, error.userInfo[@"NSLocalizedDescription"]]}];
        }
        if(block) ((void (^)()) block)(err);
    }];
}


- (void) signUpUserWithEmail:(NSString*)email password:(NSString*)password phone:(NSString*)phone role:(NSString*)role andApiKey:(NSString *)key completion:(void (^)(NSDictionary * data, NSError * error))block {
    [self.requestSerializer setValue:key forHTTPHeaderField:@"cs-api-key"];
    [self.requestSerializer setValue:[[NSLocale currentLocale] localeIdentifier] forHTTPHeaderField:@"Accept-Language"];
    NSDictionary * params = @{@"username":email,@"password":password,@"role":role};
    [self POST:@"Users/add" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSDictionary * response = responseObject[@"data"];
#ifdef DEBUG
                NSLog(@"signUpUserWithEmail response%@",response);
#endif
                
                NSHTTPURLResponse *HttpResponse = ((NSHTTPURLResponse *)[task response]);
                NSDictionary *headers = [HttpResponse allHeaderFields];
                
                if(headers[@"Token"] !=nil) {
                    NSString *base64TokenString = headers[@"Token"];
                    NSData *decodedTokenData = [[NSData alloc] initWithBase64EncodedString:base64TokenString options:0];
                    NSString *decodedTokenString = [[NSString alloc] initWithData:decodedTokenData encoding:NSUTF8StringEncoding];
                    NSData *data = [decodedTokenString dataUsingEncoding:NSUTF8StringEncoding];
                    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    self.currentToken = json[@"token"];
                    self.currentLimit = json[@"limit"];
                }
                
                //Les forHTTPHeaderField sont établis pour tous les appels suivants
                [self.requestSerializer setValue:[NSString stringWithFormat:@"%@", response[@"id"]] forHTTPHeaderField:@"cs-user-id"];// setValue:response[@"id"] fait crasher AFHTTPSessionManager car il le convertit en integer
                [self.requestSerializer setValue:self.currentToken forHTTPHeaderField:@"cs-token"];
                
                [[NSUserDefaults standardUserDefaults] setObject:email forKey:@"CurrentUserEmail"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                self.password = password;
                
                if(block) ((void (^)()) block)(response,nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err;
        NSHTTPURLResponse *response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
        if(error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey]!=nil) {
            NSInteger statusCode = response.statusCode;
            if (statusCode == 0) {
                err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:0 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
            }
            else if (statusCode > 0) {
                err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:statusCode userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Error code : %ld\n%@", (long)statusCode, error.userInfo[@"NSLocalizedDescription"]]}];
            }
        }
        if(block) ((void (^)()) block)(nil,err);
    }];
}

- (void) addUserWithEmail:(NSString*)email password:(NSString*)password phone:(NSString*)phone role:(NSString*)role andApiKey:(NSString *)key completion:(void (^)(NSDictionary * data, NSError * error))block {
    NSDictionary * params = @{@"username":email,@"password":password,@"role":role};
    [self POST:@"Users/add" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSDictionary * response = responseObject[@"data"];
#ifdef DEBUG
                NSLog(@"signUpUserWithEmail response%@",response);
#endif
                if(block) ((void (^)()) block)(response,nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err;
        NSHTTPURLResponse *response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
        if(error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey]!=nil) {
            NSInteger statusCode = response.statusCode;
            if (statusCode == 0) {
                err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:0 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
            }
            else if (statusCode > 0) {
                err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:statusCode userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Error code : %ld\n%@", (long)statusCode, error.userInfo[@"NSLocalizedDescription"]]}];
            }
        }
        if(block) ((void (^)()) block)(nil,err);
    }];
}


- (void) saveUserForId:(NSString*)userId withParams:(NSDictionary*)params completion:(void (^)(NSDictionary * response, NSError * error))block {
#ifdef DEBUG
    NSLog(@"Users/edit/%@ params: %@",userId, params);
#endif
    
    [self POST:[NSString stringWithFormat:@"Users/edit/%@", userId] parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            NSLog(@" response : %@", responseObject);
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSDictionary * response = responseObject[@"data"];
                
#ifdef DEBUG
                NSLog(@"Users/edit response%@",response);
#endif
                
                if(block) ((void (^)()) block)(response, nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil, error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"saveAccount.error : %@", error);
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil, err);
    }];
}


#pragma mark - Initialisation Models

- (void) getMaritalStatus:(NSString *)key completion:(void (^)(NSArray * maritalStatus, NSError * error))block {
    [self.requestSerializer setValue:key forHTTPHeaderField:@"cs-api-key"];
    [self.requestSerializer setValue:[[NSLocale currentLocale] localeIdentifier] forHTTPHeaderField:@"Accept-Language"];
    [self GET:@"SituationMaritals" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSLog(@"CSClient did fail to get practitioner maritalStatus with exception : %@",exception);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


- (void) getCivilitiesForRole:(NSString *)role andApiKey:(NSString *)key completion:(void (^)(NSArray * civilities, NSError * error))block {
    [self.requestSerializer setValue:key forHTTPHeaderField:@"cs-api-key"];
    [self.requestSerializer setValue:[[NSLocale currentLocale] localeIdentifier] forHTTPHeaderField:@"Accept-Language"];
    [self GET:[NSString stringWithFormat: @"civilites/for/%@", role] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSLog(@"CSClient did fail to get practitioner civilities with exception : %@",exception);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


#pragma mark - Initialisation Models - Beneficiaire
- (void) getPractitionerJobsForSearch:(NSString *)key completion:(void (^)(NSArray * jobs, NSError * error))block {
    [self.requestSerializer setValue:key forHTTPHeaderField:@"cs-api-key"];
    [self.requestSerializer setValue:[[NSLocale currentLocale] localeIdentifier] forHTTPHeaderField:@"Accept-Language"];
    [self GET:@"AnnuaireMetiers" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSLog(@"CSClient did fail to get practitioner jobs with exception : %@",exception);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


#pragma mark - Initialisation Models - Praticien
// Appellé dans FormTableViewController, dans un if ([self.path isEqualToString:@""]) {, ce qui ne semble pas être possible
// Ne sert sans doute plus
- (void) getFormItemsWithPath:(NSString*)path completion:(void (^)(NSArray * items, NSError * error))block {
    [self GET:path parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
            if(block) ((void (^)()) block)(nil, error);
            NSLog(@"form ERROR exception : %@",exception);
        }
    }
      failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSLog(@"getFormItemsWithPath Failed");
    }];
}


- (void) getPractitionerJobs:(NSString *)key completion:(void (^)(NSArray * jobs, NSError * error))block {
    [self.requestSerializer setValue:key forHTTPHeaderField:@"cs-api-key"];
    [self.requestSerializer setValue:[[NSLocale currentLocale] localeIdentifier] forHTTPHeaderField:@"Accept-Language"];
    [self GET:@"Metiers" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSLog(@"CSClient did fail to get practitioner jobs with exception : %@",exception);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


- (void) getFormeJuridiques:(NSString *)key completion:(void (^)(NSArray * formeJuridiques, NSError * error))block {
    [self.requestSerializer setValue:key forHTTPHeaderField:@"cs-api-key"];
    [self.requestSerializer setValue:[[NSLocale currentLocale] localeIdentifier] forHTTPHeaderField:@"Accept-Language"];
    [self GET:@"FormeJuridiques" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSLog(@"CSClient did fail to get practitioner FormeJuridiques with exception : %@",exception);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


// Tableau d'id des jobs ayant des spécialités
- (void) getListOfJobsWithSpecialities:(NSString *)key completion:(void (^)(NSArray * jobsSpecialities, NSError * error))block {
    [self.requestSerializer setValue:key forHTTPHeaderField:@"cs-api-key"];
    [self.requestSerializer setValue:[[NSLocale currentLocale] localeIdentifier] forHTTPHeaderField:@"Accept-Language"];
    [self GET:@"MetierSpecialites" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


- (void) getSecteurActivites:(NSString *)key completion:(void (^)(NSArray * secteurActivites, NSError * error))block {
    [self.requestSerializer setValue:key forHTTPHeaderField:@"cs-api-key"];
    [self.requestSerializer setValue:[[NSLocale currentLocale] localeIdentifier] forHTTPHeaderField:@"Accept-Language"];
    [self GET:@"Activites" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


// Cherche la liste des spécialités pour un métier donné
- (void) getSpecialitiesForJob:(NSString*)jobId completion:(void (^)(NSArray * jobsSpecialities, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"Metiers/view/%@/MetierSpecialites",jobId] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSMutableArray * jobsSpecialities = [[NSMutableArray alloc] init];
                for (NSDictionary * jobsSpecialitie in responseObject[@"data"][@"metier_specialites"]) {
                    NSDictionary * spec = @{@"id":jobsSpecialitie[@"specialite"][@"id"],
                                            @"lib_long":jobsSpecialitie[@"specialite"][@"lib_long"],
                                            @"slug":jobsSpecialitie[@"specialite"][@"slug"]};
                    [jobsSpecialities addObject:spec];
                    
                }
                if(block) ((void (^)()) block)(jobsSpecialities,nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


//TODO a traduire
- (void) getUserPractitionerRoles:(void (^)(NSArray * data, NSError * error))block {
    //NSDictionary * roles = @{@"1":NSLocalizedString(@"Administrateur", nil),
    //                             @"3":NSLocalizedString(@"Secrétaire", nil),
    //                             @"4":NSLocalizedString(@"Cassier", nil)};
    NSMutableArray * roles = [[NSMutableArray alloc] init];
    NSDictionary * spec = @{@"id":@"1", @"lib_long":NSLocalizedString(@"Administrateur", nil)};
    [roles addObject:spec];
    NSDictionary * spec1 = @{@"id":@"3", @"lib_long":NSLocalizedString(@"Secrétaire", nil)};
    [roles addObject:spec1];
    NSDictionary * spec2 = @{@"id":@"4", @"lib_long":NSLocalizedString(@"Cassier", nil)};
    [roles addObject:spec2];
    
    if(block) ((void (^)()) block)(roles,nil);
}


- (void) getMeetingStatus:(void (^)(NSDictionary * data, NSError * error))block {
    NSDictionary * roles = @{
                             @"0":NSLocalizedString(@"Attente", nil),
                             @"1":NSLocalizedString(@"Confirmé", nil),
                             @"2":NSLocalizedString(@"Annulé par le bénéficiaire", nil),
                             @"3":NSLocalizedString(@"Annulé par le praticien", nil)
                            };
    
    if(block) ((void (^)()) block)(roles,nil);
}


#pragma mark - Beneficiary

- (void) lookForPractitionersWithParameters:(NSDictionary*)params completion:(void (^)(NSArray * practitioners, NSError * error))block {
    [self POST:@"Prestataires/search" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"]) {
                if(block) ((void (^)()) block)(responseObject[@"data"][@"results"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


#pragma mark - Beneficiary - Beneficiaire

- (void) getBeneficiaryInfoAndAddressById:(NSString *)userId completion:(void (^)(NSDictionary * data, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"Beneficiaires/view/%@/Adresses", userId]
   parameters:nil
      success:^(NSURLSessionDataTask *task, id responseObject) {
          @try {
              if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                  if(block) ((void (^)()) block)(responseObject[@"data"],nil);
              }
              else {
                  NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                  if(block) ((void (^)()) block)(nil, error);
              }
          }
          @catch (NSException *exception) {
              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
              if(block) ((void (^)()) block)(nil, error);
          }
      }
      failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
          if(block) ((void (^)()) block)(nil,err);
      }];
}


//recupere juste le beneficiaire ID a partir d'un user ID
- (void) getBeneficiaryIdWithUserId:(NSString *)userId completion:(void (^)(NSDictionary * data, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"Users/view/%@/Beneficiaires", userId]
   parameters:nil
      success:^(NSURLSessionDataTask *task, id responseObject) {
          @try {
              if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                  if(responseObject[@"data"][@"beneficiaire"][@"id"]!=nil) {
                      if(block) ((void (^)()) block)(responseObject[@"data"],nil);
                  }
              }
              else {
                  NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                  if(block) ((void (^)()) block)(error);
              }
          }
          @catch (NSException *exception) {
              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
              if(block) ((void (^)()) block)(nil, error);
          }
      }
      failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
          if(block) ((void (^)()) block)(nil,err);
      }];
}


- (void) signUpBeneficiaryWithUserId:(NSString*)userId email:(NSString*)email phone:(NSString*)phone completion:(void (^)(NSDictionary * data, NSError * error))block {
    NSDictionary * params = @{@"user_id":userId,@"email":email,@"phone":phone,@"id_inscription_origine":@"1"};//,@"phone":phone,@"id_inscription_origine":@"1"}; // id_inscription_origine ???
    [self POST:@"Beneficiaires/add" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
#ifdef DEBUG
                NSLog(@"signUpBeneficiaryWithUser response%@",responseObject[@"data"]);
#endif
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


- (void) saveBeneficiaryProfileInfoById:(NSString *)beneficiaryId params:(NSDictionary*)info completion:(void (^)(NSDictionary * data, NSError * error))block {
    NSMutableDictionary * params = [[NSMutableDictionary alloc] initWithDictionary:info];
#ifdef DEBUG
    NSLog(@"Beneficiaires/edit params: %@",params);
#endif
    [self POST:[NSString stringWithFormat:@"Beneficiaires/edit/%@", beneficiaryId] parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
#ifdef DEBUG
                NSLog(@"saveBeneficiaryProfileInfo response%@",responseObject[@"data"]);
#endif
                if(block) ((void (^)()) block)(responseObject[@"data"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"beneficiaire/edit error: %@",error);
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


#pragma mark - Beneficiary - Praticien

- (void) getBeneficiaryInfoById:(NSString*)beneficiaryId completion:(void (^)(NSDictionary * data, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"Beneficiaires/view/%@", beneficiaryId]
   parameters:nil
      success:^(NSURLSessionDataTask *task, id responseObject) {
          @try {
              if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                  if(block) ((void (^)()) block)(responseObject[@"data"],nil);
              }
              else {
                  NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                  if(block) ((void (^)()) block)(nil, error);
              }
          }
          @catch (NSException *exception) {
              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
              if(block) ((void (^)()) block)(nil, error);
          }
      }
      failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
          if(block) ((void (^)()) block)(nil,err);
      }];
}


- (void) getBeneficiaryIdWithScannedResult:(NSString*)scannedResult completion:(void (^)(NSString * beneficiaryId, NSError * error))block {
#ifdef DEBUG
    NSLog(@"getBeneficiaryIdWithScannedResult %@",@{@"codecs:":scannedResult});
#endif
    
    [self POST:@"auth/authentificationQrcode" parameters:@{@"codecs":scannedResult} success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
            if(block) ((void (^)()) block)(nil,err);
        }
        
    }
    failure:^(NSURLSessionDataTask *task, NSError *error) {
       NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
       if(block) ((void (^)()) block)(nil,err);
       NSLog(@"authentification/qrcode ERROR : %@",error);
    }];
}


#pragma mark - Adresses

//target_type : 1 = Client / 2 = Prestataire / 3 = Beneficiaire / 4 = Comité / 5 = PrestataireCompte
- (void) addAddress:(NSMutableDictionary*)params completion:(void (^)(id responseObject, NSError * error))block {
    NSLog(@"addAddress self.currentToken:%@", self.currentToken);
    [self POST:@"Adresses/add" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
#ifdef DEBUG
                NSLog(@"Adresses/add response : %@", responseObject[@"data"]);
#endif
                if(block) ((void (^)()) block)(responseObject[@"data"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil, error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil, error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil, err);
    }];
}


- (void) saveAddressById:(NSString*)addressId withParams:(NSMutableDictionary*)params completion:(void (^)(id responseObject, NSError * error))block {
    NSLog(@"saveAddressById %@, %@", addressId, params);
    [self POST:[NSString stringWithFormat:@"Adresses/edit/%@", addressId] parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
#ifdef DEBUG
                NSLog(@"Adresses/edit/%@ response : %@", addressId, responseObject[@"data"]);
#endif
                if(block) ((void (^)()) block)(responseObject[@"data"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil, error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil, error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil, err);
    }];
}


- (void) deleteAddressById:(NSString*)addressId completion:(void (^)(id responseObject, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"Adresses/delete/%@", addressId] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
#ifdef DEBUG
                NSLog(@"Adresses/delete/%@ response : %@", addressId, responseObject[@"data"]);
#endif
                if(block) ((void (^)()) block)(responseObject[@"data"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil, error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil, error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil, err);
    }];
}


#pragma mark - Paiements


- (void) cancelAbonnementById:(NSString*)anId completion:(void (^)(NSString * message, NSError * error))block {
    [self POST:[NSString stringWithFormat:@"PaiementAbonnements/cancel/%@", anId] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSString * string = @"";
                if(block) ((void (^)()) block)(string,nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}



- (void) getPaiementPlanifiesAtPage:(NSString*)pageNum forBeneficiaryId:(NSString *)beneficiaryId maxResult:(NSString *)maxResult completion:(void (^)(NSArray * transactions, NSString *total, NSError * error))block {
    NSLog(@"Page : %@ / %@", pageNum, maxResult);
    [self POST:[NSString stringWithFormat:@"PaiementPlanifies/beneficiaire/%@?page=%@&limit=%@", beneficiaryId, pageNum, maxResult] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"][@"set"], responseObject[@"data"][@"total"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,nil,err);
    }];
}


- (void) getPaiementAbonnementsAtPage:(NSString*)pageNum forBeneficiaryId:(NSString *)beneficiaryId maxResult:(NSString *)maxResult completion:(void (^)(NSArray * transactions, NSString *total, NSError * error))block {
    [self POST:[NSString stringWithFormat:@"PaiementAbonnements/beneficiaire/%@?page=%@&limit=%@", beneficiaryId, pageNum, maxResult] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"][@"set"], responseObject[@"data"][@"total"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,nil,err);
    }];
}


#pragma mark - Paiements - Praticien

- (void) processPaymentWithBeneficiary:(NSString*)codeCS amount:(NSString*)amount pinCode:(NSString*)pinCode prestataire_id:(NSString*)prestataire_id prestataire_compte_id:(NSString*)prestataire_compte_id options:(NSDictionary*)options completion:(void (^)(NSDictionary * reponse, NSError * error))block {
    NSDictionary * paramsBase = @{@"prestataire_id":prestataire_id,
                                  @"prestataire_compte_id":prestataire_compte_id,
                                  @"montant":amount,
                                  @"code_cs":codeCS,
                                  @"code_pin":pinCode};//,@"phone":phone,@"id_inscription_origine":@"1"}; // id_inscription_origine ???
    
    NSMutableDictionary * params = [[NSMutableDictionary alloc] init];
    [params addEntriesFromDictionary:paramsBase];
    if(options!=nil) {
        [params addEntriesFromDictionary:options];
    }
    
    [self POST:@"Paiement" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil, error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
            NSLog(@"praticien/paiement ERROR exception : %@",exception);
            if(block) ((void (^)()) block)(nil, error);
        }
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        NSLog(@"praticien/paiement ERROR : %@",error);
        if(block) ((void (^)()) block)(nil, err);
    }];
}


- (void) getLastPaymentsForPractitionerAccount:(NSString*)accountId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * transactions, NSString *total, NSError * error))block {
    [self POST:[NSString stringWithFormat:@"PaiementPrestataires/practitioner_account/%@/%@/%@", accountId, pageNum, maxResult] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"][@"set"],responseObject[@"data"][@"total"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,nil,err);
    }];
}


- (void) simulatePayment:(NSDictionary*)params completion:(void (^)(NSDictionary * items, NSError * error))block {
    [self POST:@"Paiement/simulatePaiement" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSDictionary * data = responseObject[@"data"];
                if( [[NSString stringWithFormat:@"%@", data[@"status"]] isEqualToString:@"1"]) {
                    if(block) ((void (^)()) block)(nil);
                }
                else {
                    NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:data[@"message"]}];
                    if(block) ((void (^)()) block)(error);
                }
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
            NSLog(@"praticien/paiement ERROR exception : %@",exception);
            if(block) ((void (^)()) block)(error);
        }
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(err);
    }];
}


- (void) getPaymentsHistoryForTypeUserId:(NSString*)typeUserId userType:(NSString*)userType atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * transactions, int total, NSError * error))block {
    //params pour "type=requests&" dans la version
    NSString* params = @"";
    if([userType isEqualToString:@"affiliates"]) {
        params = @"type=requests&";
    }
    NSLog(@"%@/%@/payments?%@page=%@&limit=%@", userType, typeUserId, params, pageNum, maxResult);
    
    [self GET:[NSString stringWithFormat:@"%@/%@/payments?%@page=%@&limit=%@", userType, typeUserId, params, pageNum, maxResult] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"][@"set"], [responseObject[@"data"][@"total"] intValue], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil, nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil, nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil, nil,err);
    }];
}


- (void) cancelAskedPaymentsForCode:(NSString*)code completion:(void (^)(NSString * message, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"DemandePaiements/cancel/%@", code] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSString * string = @"";
                if(block) ((void (^)()) block)(string,nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


- (void) askForPayment:(NSDictionary*)params completion:(void (^)(NSString * message, NSError * error))block {
    [self POST:@"DemandePaiements/add" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSString * string = @"";
                if(block) ((void (^)()) block)(string,nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


- (void) getBalanceForPractitionerId:(NSString *)practitionerId completion:(void (^)(NSArray * items, NSError * error))block {
    NSDictionary * params = @{@"id":practitionerId,};
    
    [self POST:@"PaiementPrestataires/balances"
    parameters:params
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"]) {
                   if(block) block(responseObject[@"data"], nil);
               }
               else {
                   NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                   if(block) ((void (^)()) block)(nil,error);
               }
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) block(nil, error);
           }
       }
       failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSLog(@"getBalanceForAccountId : %@", error);
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) block(nil, err);
       }];
}


- (void) requestForRefund:(void (^)(NSArray * items, NSError * error))block {
    [self POST:@"Prestataires/remboursement"
    parameters:nil
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"]) {
                   NSLog(@"ret : %@", responseObject[@"data"]);
                   if(block) block(responseObject[@"data"], nil);
               }
               else {
                   NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                   if(block) ((void (^)()) block)(nil,error);
               }
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) block(nil, error);
           }
       }
       failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSLog(@"getBalanceForAccountId : %@", error);
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) block(nil, err);
       }];
}


//params {@"practitionerId":x; @"page":x;@"limit":x} en option
- (void) getRefundListForPractitioner:(NSString *)prestataireId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * items, NSString *total, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"RemboursementPrestataires/practitioner/%@/%@/%@", prestataireId, pageNum, maxResult]
   parameters:nil
      success:^(NSURLSessionDataTask *task, id responseObject) {
          @try {
              if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"]) {
                  //NSLog(@"ret : %@", responseObject[@"data"][@"set"]);
                  if(block) block(responseObject[@"data"][@"set"], responseObject[@"data"][@"total"], nil);
              }
              else {
                  NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                  if(block) ((void (^)()) block)(nil, nil,error);
              }
          }
          @catch (NSException *exception) {
              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
              if(block) block(nil, nil, error);
          }
      }
      failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSLog(@"getBalanceForAccountId : %@", error);
          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
          if(block) block(nil, nil, err);
      }];
}


- (void) getFactureByRef:(NSString *)ref completion:(void (^)(NSString * base64Pdf, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"Factures/view/%@", ref]
   parameters:nil
      success:^(NSURLSessionDataTask *task, id responseObject) {
          @try {
              if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"]) {
                  if(block) block(responseObject[@"data"], nil);
              }
              else {
                  NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                  if(block) ((void (^)()) block)(nil,error);
              }
          }
          @catch (NSException *exception) {
              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
              if(block) block(nil, error);
          }
      }
      failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSLog(@"getBalanceForAccountId : %@", error);
          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
          if(block) block(nil, err);
      }];
}


- (void) getPaymentsForBeneficiary:(NSString*)benefId completion:(void (^)(NSDictionary * items, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"Beneficiaires/view/%@/PaiementBeneficiaires", benefId] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


- (void) getPaiementPlanifiesForUserroleId:(NSString *)userroleId userrole:(NSString*)userrole atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * transactions, NSString *total, NSError * error))block {
    [self POST:[NSString stringWithFormat:@"PaiementPlanifies/%@/%@?page=%@&limit=%@", userrole, userroleId, pageNum, maxResult] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSArray * data = responseObject[@"data"][@"set"];
                if(block) ((void (^)()) block)(data, responseObject[@"data"][@"total"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,nil,err);
    }];
}


- (void) getPaiementAbonnementsForUserroleId:(NSString *)userroleId userrole:(NSString*)userrole atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * transactions, NSString *total, NSError * error))block {
    [self POST:[NSString stringWithFormat:@"PaiementAbonnements/%@/%@?page=%@&limit=%@", userrole, userroleId, pageNum, maxResult] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSArray * data = responseObject[@"data"][@"set"];
                if(block) ((void (^)()) block)(data, responseObject[@"data"][@"total"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,nil,err);
    }];
}


#pragma mark - Paiements - Beneficiaire
- (void) processPaymentForBeneficiary:(NSMutableDictionary*)paramsBase options:options completion:(void (^)(NSDictionary * reponse, NSError * error))block {
    NSMutableDictionary * params = [[NSMutableDictionary alloc] init];
    [params addEntriesFromDictionary:paramsBase];
    if(options!=nil) {
        [params addEntriesFromDictionary:options];
    }
    
    [self POST:@"Paiement" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"] ,nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil, error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
            NSLog(@"praticien/paiement ERROR exception : %@",exception);
            if(block) ((void (^)()) block)(nil, error);
        }
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:@"Connexion impossible" code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        NSLog(@"praticien/paiement ERROR : %@",error);
        if(block) ((void (^)()) block)(nil, err);
    }];
}



- (void) getAskedPaymentsForBeneficiary:(NSString*)benefId completion:(void (^)(NSArray * transactions, NSError * error))block {
    [self POST:[NSString stringWithFormat:@"Beneficiaires/view/%@/DemandePaiements", benefId] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(responseObject[@"data"][@"demande_paiements"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


//- (void) getLastPaymentsForBeneficiary:(NSString*)beneficiaryId completion:(void (^)(NSArray * transactions, NSError * error))block {
//    [self GET:[NSString stringWithFormat:@"Beneficiaires/view/%@/PaiementPrestataires",beneficiaryId] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
//        @try {
//            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
//                if(block) ((void (^)()) block)(responseObject[@"data"][@"paiement_prestataires"],nil);
//            }
//            else {
//                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
//                if(block) ((void (^)()) block)(nil,error);
//            }
//        }
//        @catch (NSException *exception) {
//            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
//            if(block) ((void (^)()) block)(nil,error);
//        }
//    } failure:^(NSURLSessionDataTask *task, NSError *error) {
//        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
//        if(block) ((void (^)()) block)(nil,err);
//    }];
//}


#pragma mark - NewsViewController


- (void) getNewsData:(void (^)(NSArray *documents, NSError *error))block {
    [self GET:@"Actualites" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"]) {
                if(block) block(responseObject[@"data"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) block(nil, error);
        }
    }
    failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) block(nil, err);
    }];
}


#pragma mark - QR Code payment

- (void) encryptString:(NSString *)string completion:(void (^)(NSString *encrypted_string, NSError *error))block {
    NSDictionary *params = @{@"string":string};
    [self POST:@"Misc/encryptString" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"]) {
                if(block) block(responseObject[@"data"][@"encrypted_string"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) block(nil, error);
        }
    }
    failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) block(nil, err);
    }];
}

- (void) decryptString:(NSString *)encrypted_string completion:(void (^)(NSDictionary *response, NSError *error))block {
    NSDictionary *params = @{@"string":encrypted_string};
    [self POST:@"Misc/decryptString" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"]) {
                if(block) block(responseObject[@"data"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) block(nil, error);
        }
    }
    failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) block(nil, err);
    }];
}


#pragma mark - Appointments

- (void) cancelAppointment:(NSString *)appointmentId completion:(void (^)(NSError *error))block {
    [self POST:[NSString stringWithFormat:@"Meetings/cancel/%@", appointmentId]
    parameters:nil
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               if(block) block(nil);
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) block(error);
           }
       }
       failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSLog(@"cancelAppointment.error : %@", error);
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) block(err);
       }];
}


#pragma mark - Appointments - Praticien

- (void) getAppointmentsWithAccountId:(NSString *)accountId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * items, int total, NSError * error))block {
    NSLog(@"accounts/%@/appointments?page=%@&limit=%@", accountId, pageNum, maxResult);
    //[self POST:[NSString stringWithFormat:@"PrestataireComptes/view/%@/Meetings", accountId]
    [self GET:[NSString stringWithFormat:@"accounts/%@/appointments?page=%@&limit=%@", accountId, pageNum, maxResult]
    parameters:nil
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               NSMutableArray * appointments = [[NSMutableArray alloc] init];
               if([responseObject[@"data"][@"total"] intValue]>0 && responseObject[@"data"][@"set"] != nil) {
                   for (NSDictionary * appointment in responseObject[@"data"][@"set"]) {
                       if( appointment && ([appointment[@"status"] intValue]==0 || [appointment[@"status"] intValue]==1) ) {//On filtre les rdv annulés
                           [appointments addObject:appointment];
                       }
                   }
               }
               // tri le appointments par ordre alphabétique du meeting_date
               NSSortDescriptor *aSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"meeting_date" ascending:YES];
               NSArray * sortedAppointments = [appointments sortedArrayUsingDescriptors:[NSArray arrayWithObjects:aSortDescriptor, nil]];
               if(block) ((void (^)()) block)(sortedAppointments, [responseObject[@"data"][@"total"] intValue], nil);
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) ((void (^)()) block)(nil, nil, error);
           }
       }
       failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSLog(@"getAppointmentsWithPractitionerId.error : %@", error);
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) ((void (^)()) block)(nil, nil, err);
       }];
}



- (void) acceptAppointment:(NSString *)appointmentId completion:(void (^)(NSDictionary *appointment, NSError *error))block {
    NSDictionary *params = @{@"id_meeting":appointmentId};
    [self POST:@"Meetings/accept"
    parameters:params
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"]) {
                   if(block) block(responseObject[@"data"], nil);
               }
               else {
                   NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                   if(block) ((void (^)()) block)(nil,error);
               }
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) block(nil, error);
           }
       }
       failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSLog(@"cancelAppointment.error : %@", error);
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) block(nil, err);
       }];
}


- (void) getTimeSlotsWithAccountId:(NSString*)accountId andAddressId:(NSString*)addressId completion:(void (^)(NSArray *pTimeSlots, NSError *error))block {
    NSDictionary *params = @{@"id_adresse":addressId};
    
    NSLog(@"getTimeSlots.params : %@", params);
    
    [self POST:[NSString stringWithFormat:@"PrestataireComptes/view/%@/MeetingConfigurations", accountId]
    parameters:params
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               NSLog(@"getTimeSlots.responseObject : %@", responseObject);
               if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"]) {
                   // Les timeSlots sont stockés en DB sous forme de String, dans ce cas on parse le JSON
                   NSString * stringJson = responseObject[@"data"][@"personnalisation"];
                   NSData* data = [stringJson dataUsingEncoding:NSUTF8StringEncoding];
                   NSArray *timeSlots = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                   if(block) block(timeSlots, nil);
               }
               else {
                   if([[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"404"]) {//@"message" : @"L'objet est introuvable."= planing non initialisé, on renvoie un json hebdomadaire vide
                       NSString * stringJson = @"[{\"day_number\":1,\"scope\":[]},{\"day_number\":2,\"scope\":[]},{\"day_number\":3,\"scope\":[]},{\"day_number\":4,\"scope\":[]},{\"day_number\":5,\"scope\":[]},{\"day_number\":6,\"scope\":[]},{\"day_number\":7,\"scope\":[]}]";
                       NSData* data = [stringJson dataUsingEncoding:NSUTF8StringEncoding];
                       NSArray *timeSlots = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                       
                       if(block) ((void (^)()) block)(timeSlots,nil);
                   }
                   else {
                       NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                       if(block) ((void (^)()) block)(nil,error);
                   }
               }
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) block(nil, error);
           }
       }
       failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSLog(@"getTimeSlotsWithPractitionerId.error : %@", error);
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) block(nil, err);
       }];
}


- (void) editTimeSlotsWithAccountId:(NSString *)accountId
                       forAddressId:(NSString *)addressId
                             config:(NSString *)config
                         completion:(void (^)(NSError * error))block {
    
    NSDictionary *params = @{@"id_adresse":addressId,
                             @"personnalisation":config};
    
    NSLog(@"ediTimeSlotWithAccountId : %@", params);
    
    
    [self POST:[NSString stringWithFormat:@"PrestataireComptes/edit/%@/MeetingConfigurations", accountId]
    parameters:params
       success:^(NSURLSessionDataTask *task, id responseObject) {
           NSLog(@"ediTimeSlotWithAccountId : %@", responseObject);
           if(block) block(nil);
       }
       failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSLog(@"ediTimeSlotWithAccountId : %@", error);
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) block(err);
       }];
}


#pragma mark - Appointments - Beneficiaire

- (void) getAppointmentsWithBeneficiaryId:(NSString *)beneficiaryId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * items, int total, NSError * error))block {
    [self POST:[NSString stringWithFormat: @"beneficiaries/%@/appointments?page=%@&limit=%@", beneficiaryId, pageNum, maxResult]
    parameters:nil
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                   if(block) ((void (^)()) block)(responseObject[@"data"][@"set"], [responseObject[@"data"][@"total"] intValue], nil);
               }
               else {
                   NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                   if(block) ((void (^)()) block)(nil, nil,error);
               }
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) ((void (^)()) block)(nil, nil, error);
           }
       } failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) ((void (^)()) block)(nil, nil, err);
       }];
}



- (void) getAppointmentHoursForPractitionerId:(NSString *)practitinerId
                                    addressId:(NSString *)addressId
                                   completion:(void (^)(NSArray * items, NSError * error))block {
    NSDictionary *params = @{@"id_adresse":addressId};
    [self POST:[NSString stringWithFormat:@"PrestataireComptes/view/%@/MeetingDates", practitinerId]
    parameters:params
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"]) {
                   if(block) block(responseObject[@"data"], nil);
               }
               else {
                   NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                   if(block) ((void (^)()) block)(nil,error);
               }
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) block(nil, error);
           }
       } failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) block(nil, err);
       }];
}


- (void) addAppointmentWithPractitionerAccountId:(NSString *)practitionerAccountId
                                andBeneficiaryId:(NSString *)beneficiaryId
                                      adresse_id:(NSString *)adresse_id
                                            date:(NSString *)date
                                            time:(NSString *)time
                               appointmentTypeId:(NSString *)appointmentTypeId
                                      completion:(void (^)(NSError * error))block {
    NSDictionary *params = @{@"id_prestataire_compte":practitionerAccountId,
                             @"id_adresse":adresse_id,
                             @"meeting_date":date,
                             @"start_time":time,
                             @"id_meeting_type":appointmentTypeId,
                             @"beneficiaire_id":beneficiaryId
                             };
    [self POST:@"Meetings/create"
    parameters:params
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               @try {
                   if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                       if(block) block(nil);
                   }
                   else {
                       NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                       if(block) block(error);
                   }
               }
               @catch (NSException *exception) {
                   NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
                   if(block) block(error);
               }
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) ((void (^)()) block)(error);
           }
       } failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) ((void (^)()) block)(err);
       }];
}


#pragma mark - Documents
// Liste des types de document KYC/HB
// withParams : isKyc, isCarebook, byPractitionerTypeId, toList
- (void) getDocumentsTypes:(NSString *)role withParams:(NSDictionary *)params completion:(void (^)(NSArray * items, NSError * error))block {
    [self POST:[NSString stringWithFormat:@"TypeDocuments/for/%@", role] parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSDictionary *data = responseObject[@"data"];
                if(data) {
                    if (data.count >0) {
                        NSMutableArray * documents = [[NSMutableArray alloc] init];
                        
                        for (NSDictionary* key in data) {
                            [documents addObject:@{@"id":key[@"id"],@"titre":key[@"titre"]}];
                        }
                        // tri les documents par ordre alphabétique du titre
                        NSSortDescriptor *aSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"titre" ascending:YES];
                        NSArray * sortedDocuments = [documents sortedArrayUsingDescriptors:[NSArray arrayWithObjects:aSortDescriptor, nil]];
                        if(block) block(sortedDocuments, nil);
                    }
                }
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) block(nil, error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) block(nil, err);
    }];
}



//isKyc=1 => kyc
//isCarebook=1 =>carnet santé
//active =>0 : en attente de validation; 1 : validé; 2 : refusé; 3 : supprimé
- (void) getDocumentsForEntity:(NSString*)entity entityId:entityId isKyc:(NSString *)isKyc isCarebook:(NSString *)isCarebook isActive:(NSString *)isActive completion:(void (^)(NSArray * items, NSError * error))block {
    NSDictionary *params;
    if([entity isEqualToString:@"Prestataire"] || [entity isEqualToString:@"PrestataireCompte"]) {
        params = @{@"isCarebook":isCarebook, @"toList":@"1"};
    }
    else {
        if([isCarebook isEqualToString:@"1"]) {
            params = @{@"isCarebook":isCarebook, @"toList":@"1"};
        }
        else {
            params = @{@"toList":@"1"};
        }
    }
    [self POST:[NSString stringWithFormat:@"Documents/for/%@/%@", entity, entityId]
    parameters:params
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"]) {
                   NSMutableArray * documents = [[NSMutableArray alloc] init];
                   NSDictionary *jsonData = responseObject[@"data"];
                   for (NSDictionary *doc in jsonData) {
                       if([[NSString stringWithFormat:@"%@",doc[@"active"]] isEqualToString:@"0"] || [[NSString stringWithFormat:@"%@",doc[@"active"]] isEqualToString:@"1"]) {
                           NSMutableDictionary * documentsAttributes = [[NSMutableDictionary alloc] initWithCapacity:5];
                           [documentsAttributes setValue:doc[@"id"] forKey:@"id"];
                           [documentsAttributes setValue:doc[@"active"] forKey:@"active"];
                           [documentsAttributes setValue:doc[@"type_document"][@"titre"] forKey:@"titre"];
                           [documentsAttributes setValue:doc[@"url_media"] forKey:@"media"];
                           if(documentsAttributes) [documents addObject:documentsAttributes];
                       }
                   }
                   // tri le documents par ordre alphabétique du titre
                   NSSortDescriptor *aSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"titre" ascending:YES];
                   NSArray * sortedDocuments = [documents sortedArrayUsingDescriptors:[NSArray arrayWithObjects:aSortDescriptor, nil]];
                   if(block) ((void (^)()) block)(sortedDocuments,nil);
               }
               else {
                   NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                   if(block) ((void (^)()) block)(nil,error);
               }
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) block(nil, error);
           }
       } failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) block(nil, err);
       }];
}



//Incompréhensible, bug sur la phase d'inscription pour la photo de profil, mais pas ailleurs
//target_type : 1 : User, 2 : Prestataire, 3 : Prestataire Compte, 4 : Bénéficiaire, 5 : Syndicat, 6 : Client ,7 : Type Assistance
- (void) addDocument:(UIImage *)image
           forUserId:(NSString *)userId
        documentType:(NSString *)documentType
          targetType:(NSString *)targetType
            targetId:(NSString *)targetId
              active:(NSString *)active
           andApiKey:(NSString *)key
          completion:(void (^)(NSString * url_media, NSError * error))block {
    
    NSDictionary *params;
    
    // TODO :  a restester  @"target_id" ne semble pas utile
    // @"target_id":target_id,
    if([targetType isEqualToString:@"2"]) {//Prestataire
        params = @{@"type_document_id":documentType,
                   @"target_type":targetType,
                   @"target_id":targetId};
    }
    else if([targetType isEqualToString:@"3"]) {//Prestataire Compte
        params = @{@"type_document_id":documentType,
                   @"target_type":targetType,
                   @"id_compte":targetId};
    }
    else if([targetType isEqualToString:@"4"]) {//Bénéficiaire
        params = @{@"type_document_id":documentType,
                   @"target_type":targetType,
                   @"active":active};
    }
    
    NSData   *imageData  = UIImageJPEGRepresentation(image, 0.6);
    NSString *requestUrl = [NSString stringWithFormat:@"%@Documents/add", self.baseURL];
    
    AFHTTPRequestSerializer *requestSerializer = [AFHTTPRequestSerializer serializer];
    [requestSerializer setValue:key forHTTPHeaderField:@"cs-api-key"];
    [requestSerializer setValue:[[NSLocale currentLocale] localeIdentifier] forHTTPHeaderField:@"Accept-Language"];
    [requestSerializer setValue:[NSString stringWithFormat:@"%@", userId] forHTTPHeaderField:@"cs-user-id"];
    [requestSerializer setValue:self.currentToken forHTTPHeaderField:@"cs-token"];
    
    NSMutableURLRequest *request = [requestSerializer multipartFormRequestWithMethod:@"POST"
                                                                           URLString:requestUrl
                                                                          parameters:params
                                                           constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                                                               [formData appendPartWithFileData:imageData name:@"file" fileName:@"photo.jpg" mimeType:@"image/jpeg"];
                                                           } error:nil];
    
    NSProgress             *progress   = nil;
    NSURLSessionUploadTask *uploadTask = [self uploadTaskWithStreamedRequest:request
                                                                    progress:&progress
                                                           completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
                                                               if (error) {
                                                                   NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
                                                                   if (block) block(nil, error);
                                                               }
                                                               else {
                                                                   if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"]) {
                                                                       NSLog(@"Documents/add responseObject data url_media : %@", responseObject[@"data"][@"url_media"]);
                                                                       if (block) block(responseObject[@"data"][@"url_media"], nil);
                                                                   }
                                                                   else {
                                                                       NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                                                                       if(block) block(nil, error);
                                                                   }
                                                               }
                                                           }];
    [uploadTask resume];
}


- (void) deleteDocument:(NSString *)documentId
            completion:(void (^)(NSError *error))block {
    [self DELETE:[NSString stringWithFormat:@"/Documents/delete/%@", documentId]
      parameters:nil
         success:^(NSURLSessionDataTask *task, id responseObject) {
             @try {
                 if(block) block(nil);
             }
             @catch (NSException *exception) {
                 NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
                 if(block) block(error);
             }
         } failure:^(NSURLSessionDataTask *task, NSError *error) {
             NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
             if(block) block(err);
         }];
}


#pragma mark - Image
/*
 ************           Les fonction getImage ne semblent plus utilisées        *********
 */
//
//- (void) getImage:(NSString *)imageName completion:(void (^)(NSArray * items, NSError * error))block {
//    [self GET:imageName parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
//          @try {
//              NSArray *data = responseObject[@"data"];
//              if(block) block(data, nil);
//          }
//          @catch (NSException *exception) {
//              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
//              if(block) block(nil, error);
//          }
//      } failure:^(NSURLSessionDataTask *task, NSError *error) {
//          NSLog(@"getDocumentsWithPractitionerId.error : %@", error);
//          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
//          if(block) block(nil, err);
//      }];
//}


#pragma mark - EULA

//slug = cgu pour beneficiaire; cga ou autres pour differents type de métiers praticien
- (void) getEulaWithSlug:(NSString*)slug completion:(void (^)(NSString *eulaHtml, NSError *error))block {
    [self GET:[NSString stringWithFormat:@"Conditions/view/%@", slug]
   parameters:nil
      success:^(NSURLSessionDataTask *task, id responseObject) {
          @try {
              if(block) block(responseObject[@"data"][@"cg"], nil);
          }
          @catch (NSException *exception) {
              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
              if(block) block(nil, error);
          }
      } failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
          if(block) block(nil, err);
      }];
}

//slug = cgu pour beneficiaire; cga ou autres pour differents type de métiers praticien
- (void) downloadEulaWithSlug:(NSString*)slug completion:(void (^)(NSString *eulaData, NSError *error))block {
    [self GET:[NSString stringWithFormat:@"Conditions/download/%@", slug]
   parameters:nil
      success:^(NSURLSessionDataTask *task, id responseObject) {
          @try {
              if(block) block(responseObject[@"data"], nil);
          }
          @catch (NSException *exception) {
              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
              if(block) block(nil, error);
          }
      } failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
          if(block) block(nil, err);
      }];
}




#pragma mark - Push Notification

- (void) addDeviceTokenForPushNotificationWithUserId:(NSString *)target_id
                                         target_type:(NSString *)target_type
                                           device_id:(NSString *)device_id
                                        device_token:(NSString *)device_token
                                          completion:(void (^)(NSError * error))block {
    NSDictionary *params = @{  @"target_id":target_id,
                               @"target_type":target_type,
                               @"device_id":device_id,
                               @"device_token":device_token,
                               @"device_type":@"1"};
    NSLog(@"addDeviceTokenForPushNotificationWithUserId.params : %@", params);
    
    [self POST:@"DeviceTokens/add" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if(responseObject[@"deviceToken"]) {
                if(block) block(nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) block(error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(error);
        }
    }
       failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSLog(@"addDeviceTokenForPushNotificationWithUserId.error : %@", error);
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) block(err);
       }];
}




#pragma mark - ************************************************* BENEFICIAIRE *******************************************************

#pragma mark - Accompagnement

- (void) getAssistanceInfo:(void (^)(NSDictionary * info, NSError * error))block {
    [self GET:@"Beneficiaires/boutonAssistance" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(responseObject[@"data"]) {
                    if(![responseObject[@"data"] isKindOfClass:[NSNull class]]) {
                        [[NSUserDefaults standardUserDefaults] setObject:responseObject[@"data"] forKey:@"BOUTON_ASSISTANCE"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                    }
                }
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
        
        if(error.code == 404 && [[NSUserDefaults standardUserDefaults] objectForKey:@"BOUTON_ASSISTANCE"]) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"BOUTON_ASSISTANCE"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }];
    
}


#pragma mark - Misc


- (void) findDocument:(NSDictionary*)params completion:(void (^)(NSString * encodedImage, NSError * error))block {
    [self POST:@"Documents/find"
    parameters:params
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               NSString *document=nil;
               if(responseObject[@"data"]) {
                   document = [NSString stringWithFormat:@"data:image/%@;base64,%@", responseObject[@"data"][@"ext"], responseObject[@"data"][@"image"]];
               }
               if(block) block(document, nil);
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) block(nil, error);
           }
       } failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) block(nil, err);
       }];
}


// En v2, on ne récupère plus de pin pour les jobs
- (void) getPin:(NSString *)url completion:(void (^)(UIImage * image))block {
    NSLog(@"getPin.url : %@", url);
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    AFHTTPRequestOperation *requestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    requestOperation.responseSerializer = [AFImageResponseSerializer serializer];
    [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Response: %@", responseObject);
        if(block) ((void (^)()) block)(responseObject);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Image error: %@", error);
        if(block) ((void (^)()) block)(nil);
    }];
    [requestOperation start];
}


#pragma mark - Emergency favorites

// Temporairement en dur, il faudra une route...
- (void) getEmergencyNumbers:(void (^)(NSArray * items, NSError * error))block {
    NSLocale *currentLocale = [NSLocale currentLocale];
    NSString *countryCode = [currentLocale objectForKey:NSLocaleCountryCode];
    NSDictionary *dataWW = @{
                             @"FR":@[
                                     @{@"title": NSLocalizedString(@"Appel d'urgence européen", nil), @"number": @"112", @"SMS": @"0"},
                                     @{@"title": NSLocalizedString(@"SMS pour sourds et malentendants", nil), @"number": @"114", @"SMS": @"1"},
                                     @{@"title": NSLocalizedString(@"Pharmacie de garde", nil), @"number": @"3237", @"SMS": @"0"},
                                     @{@"title": NSLocalizedString(@"Police", nil), @"number": @"17", @"SMS": @"0"},
                                     @{@"title": NSLocalizedString(@"Pompiers", nil), @"number": @"18", @"SMS": @"0"},
                                     @{@"title": NSLocalizedString(@"SAMU", nil), @"number": @"15", @"SMS": @"0"},
                                     @{@"title": NSLocalizedString(@"SOS médecin", nil), @"number": @"3624", @"SMS": @"0"},
                                     ],
                             @"GB":@[
                                     @{@"title": @"Emergency Call", @"number": @"999", @"SMS": @"0"},
                                     @{@"title": @"European Emergency Call", @"number": @"112", @"SMS": @"0"},
                                     @{@"title": @"Police", @"number": @"101", @"SMS": @"0"},
                                     @{@"title": @"National non-emergency medical number", @"number": @"111", @"SMS": @"0"},
                                     @{@"title": @"NHS Direct (24 hour health helpline)", @"number": @"111", @"SMS": @"0"},
                                     @{@"title": @"SMS for the deaf and hard of hearing", @"number": @"111", @"SMS": @"1"},
                                     ]
                             };
    NSArray *data = [dataWW objectForKey:countryCode];
    if(block) block(data, nil);
}



- (void) getEmergencyFavoritesForBeneficiaryId:(NSString *)beneficiaryId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * items, NSString *total, NSError * error))block {
    //[self GET:[NSString stringWithFormat:@"Beneficiaires/view/%@/favoris", beneficiaryId]
    [self GET:[NSString stringWithFormat:@"beneficiaries/%@/favorites?page=%@&limit=%@", beneficiaryId, pageNum, maxResult]
   parameters:nil
      success:^(NSURLSessionDataTask *task, id responseObject) {
          @try {
              if(block) ((void (^)()) block)(responseObject[@"data"][@"set"], responseObject[@"data"][@"total"], nil);
          }
          @catch (NSException *exception) {
              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
              if(block) ((void (^)()) block)(nil, nil, error);
          }
      } failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSLog(@"getDocumentsWithPractitionerId.error : %@", error);
          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
          if(block) ((void (^)()) block)(nil, nil, err);
      }];
}



- (void) addEmergencyFavoriteWithPractitienAccountId:(NSString *)practitienAccountId beneficiaryId:(NSString *)beneficiaryId addressId:(NSString *)addressId completion:(void (^)(NSError * error))block {
    NSDictionary *params = @{@"prestataire_compte_id":practitienAccountId,
                             @"adresse_id":addressId};
    [self POST:[NSString stringWithFormat:@"/Beneficiaires/add/%@/favoris", beneficiaryId]
    parameters:params
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                   if(block) block(nil);
               }
               else {
                   NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                   if(block) ((void (^)()) block)(error);
               }
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) block(error);
           }
       } failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSLog(@"addEmergencyFavoriteWithPractitienAccountId.error : %@", error);
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) block(err);
       }];
}



- (void) deleteEmergencyFavorite:(NSString *)favoriteId forBeneficiaryId:(NSString *)beneficiaryId completion:(void (^)(NSError *error))block {
    NSDictionary *params = @{@"favoris_id":favoriteId};
    [self POST:[NSString stringWithFormat:@"Beneficiaires/delete/%@/favoris", beneficiaryId]
    parameters:params
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                   if(block) block(nil);
               }
               else {
                   NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                   if(block) block(error);
               }
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) block(error);
           }
       } failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSLog(@"deleteEmergencyFavorite.error : %@", error);
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) block(err);
       }];
}


#pragma mark - CreditCards

- (void) getCreditCards:(void (^)(NSArray* cards,NSError * error))block {
    [self GET:@"wallet/cards" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
#ifdef DEBUG
                NSLog(@"wallet/cards response : %@",responseObject[@"data"][@"cardsList"][@"cards"]);
#endif
                if(block) ((void (^)()) block)(responseObject[@"data"][@"cardsList"][@"cards"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}



- (void) addCreditCard:(NSMutableDictionary *)params completion:(void (^)(NSArray * result, NSError * error))block {
    [self POST:@"wallet/create" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSDictionary * response = responseObject[@"data"];
#ifdef DEBUG
                NSLog(@"wallet/card add response%@",response);
#endif
                if(block) ((void (^)()) block)(responseObject[@"data"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}



- (void) disableCreditCard:(NSString *)cardIndex completion:(void (^)(NSArray * result, NSError * error))block {
#ifdef DEBUG
    NSLog(@"wallet/card disable credit card with index: %@",cardIndex);
#endif
    [self POST:@"wallet/disable" parameters:@{@"cardInd":cardIndex} success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            NSLog(@" response : %@", responseObject);
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
#ifdef DEBUG
                NSLog(@"wallet/card disable response%@",responseObject[@"data"]);
#endif
                if(block) ((void (^)()) block)(responseObject[@"data"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}



- (void) setFavoriteCreditCard:(NSString *)cardIndex completion:(void (^)(NSError * error))block {
    [self POST:@"wallet/card/favorite" parameters:@{@"cardInd":cardIndex} success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if([[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(error);
        }
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(err);
    }];
}



- (void) setNameForCreditCard:(NSMutableDictionary *)params completion:(void (^)(NSError * error))block {
    [self POST:@"wallet/update" parameters:@{@"Card[ind]":params[@"index"],@"Card[name]":params[@"libelle"],@"Card[favorite]":params[@"favorite"]} success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                if(block) ((void (^)()) block)(nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        //NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:error.localizedDescription}];
        if(block) ((void (^)()) block)(err);
    }];
}






#pragma mark - *************************************************** PRATICIEN ********************************************************

#pragma mark - Practitioner
//recupere juste le beneficiaire ID a partir d'un user ID
- (void) getPractitionerInfoWithUserId:(NSString *)userId completion:(void (^)(NSDictionary * data, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"Users/view/%@/Prestataires", userId]
   parameters:nil
      success:^(NSURLSessionDataTask *task, id responseObject) {
          @try {
              if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                  if(responseObject[@"data"][@"user_prestataire"][@"id"]!=nil) {
                      if(block) ((void (^)()) block)(responseObject[@"data"],nil);
                  }
              }
              else {
                  NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                  if(block) ((void (^)()) block)(error);
              }
          }
          @catch (NSException *exception) {
              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
              if(block) ((void (^)()) block)(nil, error);
          }
      }
      failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
          if(block) ((void (^)()) block)(nil,err);
      }];
}


- (void) getPractitionerCompteById:(NSString*)practitionerCompteId completion:(void (^)(NSDictionary * data, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"PrestataireComptes/view/%@", practitionerCompteId]
   parameters:nil
      success:^(NSURLSessionDataTask *task, id responseObject) {
          @try {
              if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                  if(block) ((void (^)()) block)(responseObject[@"data"],nil);
              }
              else {
                  NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                  if(block) ((void (^)()) block)(nil, error);
              }
          }
          @catch (NSException *exception) {
              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
              if(block) ((void (^)()) block)(nil, error);
          }
      }
      failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
          if(block) ((void (^)()) block)(nil,err);
      }];
}
- (void) getPractitionerCompteByIdOld:(NSString*)practitionerId completion:(void (^)(NSArray * data, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"Prestataires/view/%@/PrestataireComptes", practitionerId]
   parameters:nil
      success:^(NSURLSessionDataTask *task, id responseObject) {
          @try {
              if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                  if(block) ((void (^)()) block)(responseObject[@"data"][@"prestataire_comptes"],nil);
              }
              else {
                  NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                  if(block) ((void (^)()) block)(nil, error);
              }
          }
          @catch (NSException *exception) {
              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
              if(block) ((void (^)()) block)(nil, error);
          }
      }
      failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
          if(block) ((void (^)()) block)(nil,err);
      }];
}


- (void) getAccountForId:(NSString*)practitionerId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * data, int total, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"affiliates/%@/accounts?filters[active][value]=3&filters[active][operator]=%@&page=%@&limit=%@", practitionerId, @"%3C", pageNum, maxResult]
   parameters:nil
      success:^(NSURLSessionDataTask *task, id responseObject) {
          @try {
              if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                  if(block) ((void (^)()) block)(responseObject[@"data"][@"set"],[responseObject[@"data"][@"total"] intValue],nil);
              }
              else {
                  NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                  if(block) ((void (^)()) block)(nil, nil, error);
              }
          }
          @catch (NSException *exception) {
              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
              if(block) ((void (^)()) block)(nil, nil, error);
          }
      }
      failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
          if(block) ((void (^)()) block)(nil, nil, err);
      }];
}


- (void) getAddressForEntity:(NSString*)entity entityId:(NSString*)entityId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * data, int total, NSError * error))block {
    NSLog(@"url : %@/%@/addresses?filters[active][value]=3&filters[active][operator]=%@&page=%@&limit=%@", entity, entityId, @"%3C", pageNum, maxResult);
    // [self POST:[NSString stringWithFormat:@"%@/view/%@/Adresses", entity, entityId]

    [self GET:[NSString stringWithFormat:@"%@/%@/addresses?filters[active][value]=3&filters[active][operator]=%@&page=%@&limit=%@", entity, entityId, @"%3C", pageNum, maxResult]
    parameters:nil
       success:^(NSURLSessionDataTask *task, id responseObject) {
           @try {
               if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                   if(block) ((void (^)()) block)(responseObject[@"data"][@"set"], [responseObject[@"data"][@"total"] intValue], nil);
               }
               else {
                   NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                   if(block) ((void (^)()) block)(nil, nil, error);
               }
           }
           @catch (NSException *exception) {
               NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
               if(block) ((void (^)()) block)(nil, nil, error);
           }
       } failure:^(NSURLSessionDataTask *task, NSError *error) {
           NSLog(@"getAppointmentsWithPractitionerId.error : %@", error);
           NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
           if(block) ((void (^)()) block)(nil, nil, err);
       }];
}


- (void) signUpPractitionerWithUserId:(NSString*)userId type_prestataire_id:(NSString*)type_prestataire_id completion:(void (^)(NSDictionary * data, NSError * error))block {
    NSDictionary * params = @{@"user_id":userId,@"type_prestataire_id":type_prestataire_id,@"id_inscription_origine":@"1"};
    [self POST:@"Prestataires/add" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
#ifdef DEBUG
                NSLog(@"signUpPractitionerWithUserId response%@",responseObject[@"data"]);
#endif
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


- (void) addAccount:(NSDictionary *)params completion:(void (^)(id responseObject, NSError * error))block {
    [self POST:@"PrestataireComptes/add" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSDictionary * response = responseObject[@"data"];
#ifdef DEBUG
                NSLog(@"signUpPractitionerCompteWithUser response%@",response);
#endif
                if(block) ((void (^)()) block)(response,nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}



- (void) deleteAccountById:(NSString*)accountId completion:(void (^)(id responseObject, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"PrestataireComptes/delete/%@", accountId] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                NSDictionary * response = responseObject[@"data"];
#ifdef DEBUG
                NSLog(@"deleteAccountById response:%@",response);
#endif
                if(block) ((void (^)()) block)(response,nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


- (void) savePractitionerForId:(NSString*)PractitionerId withParams:(NSDictionary*)params completion:(void (^)(id responseObject, NSError * error))block {
#ifdef DEBUG
    NSLog(@"Prestataires/edit/%@ params: %@",PractitionerId, params);
#endif
    
    [self POST:[NSString stringWithFormat:@"Prestataires/edit/%@", PractitionerId] parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
#ifdef DEBUG
                NSLog(@"praticien/edit response%@",responseObject[@"data"]);
#endif
                if(block) ((void (^)()) block)(responseObject,nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


- (void) saveAccountForId:(NSString*)accountId withParams:(NSMutableDictionary*)params completion:(void (^)(NSDictionary * response, NSError * error))block {
#ifdef DEBUG
    NSLog(@"PrestataireComptes/edit/%@ params: %@",accountId, params);
#endif
    
    [self POST:[NSString stringWithFormat:@"PrestataireComptes/edit/%@", accountId] parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            NSLog(@" response : %@", responseObject);
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                
                NSDictionary * response = responseObject[@"data"];
                
#ifdef DEBUG
                NSLog(@"praticien/compte/edit response%@",response);
#endif
                
                //                if(response[@"compte_id"]) account.objectId = response[@"compte_id"];
                //                if(response[@"taux"]) account.csRate = response[@"taux"];
                
                if(block) ((void (^)()) block)(response, nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil, error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
        
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"saveAccount.error : %@", error);
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil, err);
    }];
}


- (void) getUserPractitionerForId:(NSString*)practitionerId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * data, NSString *total, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"affiliates/%@/interlocutors?filters[active][value]=3&filters[active][operator]=%@&page=%@&limit=%@", practitionerId, @"%3C", pageNum, maxResult]
   parameters:nil
      success:^(NSURLSessionDataTask *task, id responseObject) {
          @try {
              if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
                  if(block) ((void (^)()) block)(responseObject[@"data"][@"set"],responseObject[@"data"][@"total"],nil);
              }
              else {
                  NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                  if(block) ((void (^)()) block)(nil, nil, error);
              }
          }
          @catch (NSException *exception) {
              NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
              if(block) ((void (^)()) block)(nil, nil, error);
          }
      }
      failure:^(NSURLSessionDataTask *task, NSError *error) {
          NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
          if(block) ((void (^)()) block)(nil, nil, err);
      }];
}


- (void) saveUserPractitionerForId:(NSString*)userPractitionerId withParams:(NSDictionary*)params completion:(void (^)(NSDictionary * response, NSError * error))block {
#ifdef DEBUG
    NSLog(@"UserPrestataires/edit/%@ params: %@",userPractitionerId, params);
#endif
    
    [self POST:[NSString stringWithFormat:@"UserPrestataires/edit/%@", userPractitionerId] parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            NSLog(@" response : %@", responseObject);
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
#ifdef DEBUG
                NSLog(@"UserPrestataires/edit response%@",responseObject);
#endif
                
                if(block) ((void (^)()) block)(responseObject[@"data"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil, error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"saveAccount.error : %@", error);
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil, err);
    }];
}


//role_id : 1= administrateur / 2 = Comptable / 3 = Secretaire / 4 = Caissier
- (void) addUserPractitionerWithUserId:(NSString*)userId andPrestataireId:(NSString*)prestataireId andParams:(NSMutableDictionary*)params completion:(void (^)(NSDictionary * data, NSError * error))block {
    NSDictionary * paramsBase = @{@"user_id":userId,
                                  @"prestataire_id":prestataireId};
    
    [params addEntriesFromDictionary:paramsBase];
    //NSDictionary * params = @{@"user_id":userId,@"prestataire_id":prestataireId,@"role_id":role_id};
    NSLog(@"-------------USERID : %@, -------------PRESTATAIREID : %@", userId, prestataireId);
    [self POST:@"UserPrestataires/add" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
#ifdef DEBUG
                NSLog(@"signUpUserPractitionerWithUser response%@",responseObject[@"data"]);
#endif
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}


- (void) deleteUserPractitionerForId:(NSString*)userPractitionerId completion:(void (^)(NSDictionary * response, NSError * error))block {
    [self DELETE:[NSString stringWithFormat:@"interlocutor/%@", userPractitionerId] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            NSLog(@" response : %@", responseObject);
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
#ifdef DEBUG
                NSLog(@"UserPrestataires/edit response%@",responseObject);
#endif
                
                if(block) ((void (^)()) block)(responseObject[@"data"], nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil, error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"saveAccount.error : %@", error);
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil, err);
    }];
}


#pragma mark - Practitien - Beneficiaire

- (void) getPractitionerById:(NSString*)practitionerId completion:(void (^)(NSDictionary * data, NSError * error))block {
    [self GET:[NSString stringWithFormat:@"Prestataires/view/%@", practitionerId] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        @try {
            if( [[NSString stringWithFormat:@"%@", responseObject[@"success"]] isEqualToString:@"1"] && [[NSString stringWithFormat:@"%@", responseObject[@"code"]] isEqualToString:@"200"] ) {
#ifdef DEBUG
                NSLog(@"getPractitionerById responseObject %@",responseObject);
#endif
                if(block) ((void (^)()) block)(responseObject[@"data"],nil);
            }
            else {
                NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:responseObject[@"message"]}];
                if(block) ((void (^)()) block)(nil,error);
            }
        }
        @catch (NSException *exception) {
            NSError * error = [[NSError alloc] initWithDomain:[self.baseURL absoluteString] code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Oups, une erreur inconnue est survenue...", nil)}];
            if(block) ((void (^)()) block)(nil,error);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSError * err = [[NSError alloc] initWithDomain:NSLocalizedString(@"Connexion impossible", nil) code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Erreur de connexion.\n\nMerci de vérifier votre connexion internet et de recommencer.", nil)}];
        if(block) ((void (^)()) block)(nil,err);
    }];
}

@end
