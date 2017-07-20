//
//  CSClientV2.h
//  ChequeSante
//
//  Created by Richard on 28/09/2016.
//  Copyright (c) 2017 CareLabs. All rights reserved.
//
//
// ****************************************************************************
//
//          Librairie CSClient V2.1
//
// ****************************************************************************

#import <Foundation/Foundation.h>
#import "AFNetworking.h"



@interface CSClientV2 : AFHTTPSessionManager

@property (nonatomic, strong) NSDate * endSessionDate;
@property (nonatomic, strong) NSString * password;
@property (nonatomic, strong) NSString * currentToken;//Tokken d'identification renvoyé par l'API
@property (nonatomic, strong) NSString * currentLimit;//Date limite du Tokken d'identification renvoyé par l'API

@property BOOL shouldAutoLogout;

+ (CSClientV2*)sharedClient:(NSString*)url;


#pragma mark - Utils
- (void) cacheJSON:(id)JSON withKey:(NSString*)key;
- (id) getCachedJSONWithKey:(NSString*)key;


#pragma mark - Authentification
- (void) authentifyUserWithEmail:(NSString*)email password:(NSString*)password andApiKey:(NSString *)key completion:(void (^)(NSDictionary * data, NSError * error))block;
- (void) logout;
- (void) reinitializePasswordForEmail:(NSString*)email andApiKey:(NSString *)key completion:(void (^)(NSError * error))block;
- (void) signUpUserWithEmail:(NSString*)email password:(NSString*)password phone:(NSString*)phone role:(NSString*)role andApiKey:(NSString *)key completion:(void (^)(NSDictionary * data, NSError * error))block;
- (void) addUserWithEmail:(NSString*)email password:(NSString*)password phone:(NSString*)phone role:(NSString*)role andApiKey:(NSString *)key completion:(void (^)(NSDictionary * data, NSError * error))block;
- (void) saveUserForId:(NSString*)userId withParams:(NSDictionary*)params completion:(void (^)(NSDictionary * response, NSError * error))block;


#pragma mark - Initialisation Models
- (void) getMaritalStatus:(NSString *)key completion:(void (^)(NSArray * maritalStatus, NSError * error))block;
- (void) getCivilitiesForRole:(NSString *)role andApiKey:(NSString *)key completion:(void (^)(NSArray * civilities, NSError * error))block;
#pragma mark - Initialisation Models - Beneficiaire
- (void) getPractitionerJobsForSearch:(NSString *)key completion:(void (^)(NSArray * jobs, NSError * error))block;
#pragma mark - Initialisation Models - Praticien
- (void) getFormItemsWithPath:(NSString*)path completion:(void (^)(NSArray * items, NSError * error))block;
- (void) getPractitionerJobs:(NSString *)key completion:(void (^)(NSArray * payments, NSError * error))block;
- (void) getFormeJuridiques:(NSString *)key completion:(void (^)(NSArray * formeJuridiques, NSError * error))block;
- (void) getListOfJobsWithSpecialities:(NSString *)key completion:(void (^)(NSArray * jobsSpecialities, NSError * error))block;
- (void) getSecteurActivites:(NSString *)key completion:(void (^)(NSArray * secteurActivites, NSError * error))block;
- (void) getSpecialitiesForJob:(NSString*)jobId completion:(void (^)(NSArray * jobsSpecialities, NSError * error))block;
- (void) getUserPractitionerRoles:(void (^)(NSArray * data, NSError * error))block;
- (void) getMeetingStatus:(void (^)(NSDictionary * data, NSError * error))block;
- (void) getDocumentStatus:(void (^)(NSDictionary * data, NSError * error))block;

#pragma mark - Beneficiary
- (void) lookForPractitionersWithParameters:(NSDictionary*)params completion:(void (^)(NSArray * practitioners, NSError * error))block;
#pragma mark - Beneficiary - Beneficiaire
- (void) getBeneficiaryInfoAndAddressById:(NSString *)userId completion:(void (^)(NSDictionary * data, NSError * error))block;
- (void) getBeneficiaryIdWithUserId:(NSString *)userId completion:(void (^)(NSDictionary * data, NSError * error))block;
- (void) signUpBeneficiaryWithUserId:(NSString*)userId email:(NSString*)email phone:(NSString*)phone completion:(void (^)(NSDictionary * data, NSError * error))block;
- (void) saveBeneficiaryProfileInfoById:(NSString *)beneficiaryId params:(NSDictionary*)info completion:(void (^)(NSDictionary * data, NSError * error))block;
#pragma mark - Beneficiary - Praticien
- (void) getBeneficiaryInfoById:(NSString*)beneficiaryId completion:(void (^)(NSDictionary * data, NSError * error))block;
- (void) getBeneficiaryIdWithScannedResult:(NSString*)scannedResult completion:(void (^)(NSString * beneficiaryId, NSError * error))block;


#pragma mark - Adresses
- (void) addAddress:(NSDictionary*)params completion:(void (^)(id responseObject, NSError * error))block;
- (void) saveAddressById:(NSString*)addressId withParams:(NSMutableDictionary*)params completion:(void (^)(id responseObject, NSError * error))block;
- (void) deleteAddressById:(NSString*)addressId completion:(void (^)(id responseObject, NSError * error))block;


#pragma mark - Paiements
- (void) cancelAbonnementById:(NSString*)anId completion:(void (^)(NSString * message, NSError * error))block;
- (void) getPaiementPlanifiesForUserroleId:(NSString *)userroleId userrole:(NSString*)userrole atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * transactions, NSString *total, NSError * error))block;
- (void) getPaiementAbonnementsForUserroleId:(NSString *)userroleId userrole:(NSString*)userrole atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * transactions, NSString *total, NSError * error))block;

#pragma mark - Paiements - Praticien
- (void) processPaymentWithBeneficiary:(NSString*)codeCS amount:(NSString*)amount pinCode:(NSString*)pinCode prestataire_id:(NSString*)prestataire_id prestataire_compte_id:(NSString*)prestataire_compte_id options:(NSDictionary*)options completion:(void (^)(NSDictionary * reponse, NSError * error))block;

- (void) getLastPaymentsForPractitionerAccount:(NSString*)accountId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * transactions, NSString *total, NSError * error))block;
- (void) simulatePayment:(NSDictionary*)params completion:(void (^)(NSDictionary * items, NSError * error))block;

- (void) getPaymentsHistoryForTypeUserId:(NSString*)typeUserId userType:(NSString*)userType atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * transactions, int total, NSError * error))block;
- (void) cancelAskedPaymentsForCode:(NSString*)code completion:(void (^)(NSString * message, NSError * error))block;
- (void) askForPayment:(NSDictionary*)params completion:(void (^)(NSString * message, NSError * error))block;

- (void) getBalanceForPractitionerId:(NSString *)practitionerId completion:(void (^)(NSArray * items, NSError * error))block;
- (void) getRefundListForPractitioner:(NSString *)prestataireId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * items, NSString *total, NSError * error))block;
- (void) requestForRefund:(void (^)(NSArray * items, NSError * error))block;
- (void) getFactureByRef:(NSString *)ref completion:(void (^)(NSString * base64Pdf, NSError * error))block;
- (void) getPaymentsForBeneficiary:(NSString*)benefId completion:(void (^)(NSDictionary * items, NSError * error))block;

#pragma mark - Paiements - Beneficiaire
- (void) processPaymentForBeneficiary:(NSMutableDictionary*)paramsBase options:(NSDictionary*)options completion:(void (^)(NSDictionary * reponse, NSError * error))block;
- (void) getAskedPaymentsForBeneficiary:(NSString*)benefId completion:(void (^)(NSArray * transactions, NSError * error))block;
//- (void) getLastPaymentsForBeneficiary:(NSString*)beneficiaryId completion:(void (^)(NSArray * transactions, NSError * error))block;


#pragma mark - QR Code payment
- (void) encryptString:(NSString *)string completion:(void (^)(NSString *encrypted_string, NSError *error))block;
- (void) decryptString:(NSString *)encrypted_string completion:(void (^)(NSDictionary *response, NSError *error))block;


#pragma mark - Appointments
- (void) cancelAppointment:(NSString *)appointmentId completion:(void (^)(NSError *error))block;
#pragma mark - Appointments - Praticien
- (void) getAppointmentsWithAccountId:(NSString *)accountId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * items, int total, NSError * error))block;
- (void) acceptAppointment:(NSString *)appointmentId completion:(void (^)(NSDictionary *appointment, NSError *error))block;
- (void) getTimeSlotsWithAccountId:(NSString*)accountId andAddressId:(NSString*)addressId completion:(void (^)(NSArray *pTimeSlots, NSError *error))block;
- (void) editTimeSlotsWithAccountId:(NSString *)accountId
                       forAddressId:(NSString *)addressId
                             config:(NSString *)config
                         completion:(void (^)(NSError * error))block;
#pragma mark - Appointments - Beneficiaire
- (void) getAppointmentsWithBeneficiaryId:(NSString *)beneficiaryId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * items, int total, NSError * error))block;
- (void) getAppointmentHoursForPractitionerId:(NSString *)practitinerId
                                    addressId:(NSString *)addressId
                                   completion:(void (^)(NSArray * items, NSError * error))block;
- (void) addAppointmentWithPractitionerAccountId:(NSString *)practitionerAccountId
                                andBeneficiaryId:(NSString *)beneficiaryId
                                      adresse_id:(NSString *)adresse_id
                                            date:(NSString *)date
                                            time:(NSString *)time
                               appointmentTypeId:(NSString *)appointmentTypeId
                                      completion:(void (^)(NSError * error))block;


#pragma mark - Documents
- (void) getDocumentsTypes:(NSString *)role withParams:(NSDictionary *)params completion:(void (^)(NSArray * items, NSError * error))block;
- (void) getDocumentsForEntityOld:(NSString*)entity entityId:entityId isKyc:(NSString *)isKyc isCarebook:(NSString *)isCarebook isActive:(NSString *)isActive completion:(void (^)(NSArray * items, NSError * error))block;
- (void) getDocumentsForEntity:(NSString*)entity entityId:entityId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult withParams:(NSString *)params completion:(void (^)(NSArray * items, NSString *total, NSError * error))block;

- (void) addDocument:(UIImage *)image
           forUserId:(NSString *)userId
        documentType:(NSString *)documentType
          targetType:(NSString *)targetType
            targetId:(NSString *)targetId
              active:(NSString *)active
           andApiKey:(NSString *)key
          completion:(void (^)(NSString * url_media, NSError * error))block;
- (void) deleteDocument:(NSString *)documentId completion:(void (^)(NSError *error))block;


#pragma mark - News
- (void) getNewsData:(void (^)(NSArray *documents, NSError *error))block;


#pragma mark - EULA
- (void) getEulaWithSlug:(NSString*)slug completion:(void (^)(NSString *eulaHtml, NSError *error))block;
- (void) downloadEulaWithSlug:(NSString*)slug completion:(void (^)(NSString *eulaData, NSError *error))block;


#pragma mark - Push Notification
- (void) addDeviceTokenForPushNotificationWithUserId:(NSString *)target_id
                                        target_type:(NSString *)target_type
                                          device_id:(NSString *)device_id
                                       device_token:(NSString *)device_token
                                         completion:(void (^)(NSError * error))block;





#pragma mark - ************************************************* BENEFICIAIRE *******************************************************

#pragma mark - Accompagnement
- (void) getAssistanceInfo:(void (^)(NSDictionary * info, NSError * error))block;


#pragma mark - Misc
- (void) findDocument:(NSDictionary*)params completion:(void (^)(NSString * encodedImage, NSError * error))block;
- (void) getPin:(NSString *)url completion:(void (^)(UIImage * image))block;


#pragma mark - Emergency favorites
- (void) getEmergencyNumbers:(void (^)(NSArray * items, NSError * error))block;
- (void) getEmergencyFavoritesForBeneficiaryId:(NSString *)beneficiaryId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * items, NSString *total, NSError * error))block;
- (void) addEmergencyFavoriteWithPractitienAccountId:(NSString *)practitienAccountId beneficiaryId:(NSString *)beneficiaryId addressId:(NSString *)addressId completion:(void (^)(NSError * error))block;
- (void) deleteEmergencyFavorite:(NSString *)favoriteId forBeneficiaryId:(NSString *)beneficiaryId completion:(void (^)(NSError *error))block;


#pragma mark - CreditCards
- (void) getCreditCards:(void (^)(NSArray* cards,NSError * error))block;
- (void) addCreditCard:(NSMutableDictionary *)params completion:(void (^)(NSArray * result, NSError * error))block;
- (void) disableCreditCard:(NSString *)cardIndex completion:(void (^)(NSArray * result, NSError * error))block;
- (void) setFavoriteCreditCard:(NSString *)cardIndex completion:(void (^)(NSError * error))block;
- (void) setNameForCreditCard:(NSMutableDictionary *)params completion:(void (^)(NSError * error))block;






#pragma mark - *************************************************** PRATICIEN ********************************************************

#pragma mark - Practitien
- (void) getPractitionerInfoWithUserId:(NSString *)userId completion:(void (^)(NSDictionary * data, NSError * error))block;
- (void) getPractitionerCompteById:(NSString*)practitionerId completion:(void (^)(NSDictionary * data, NSError * error))block;
- (void) getAccountForId:(NSString*)practitionerId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * data, int total, NSError * error))block;
- (void) getAddressForEntity:(NSString*)entity entityId:(NSString*)entityId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * data, int total, NSError * error))block;
- (void) signUpPractitionerWithUserId:(NSString*)userId type_prestataire_id:(NSString*)type_prestataire_id completion:(void (^)(NSDictionary * data, NSError * error))block;
- (void) addAccount:(NSDictionary*)params completion:(void (^)(id responseObject, NSError * error))block ;
- (void) deleteAccountById:(NSString*)accountId completion:(void (^)(id responseObject, NSError * error))block;
- (void) savePractitionerForId:(NSString*)PractitionerId withParams:(NSDictionary*)params completion:(void (^)(id responseObject, NSError * error))block;
- (void) saveAccountForId:(NSString*)accountId withParams:(NSMutableDictionary*)params completion:(void (^)(NSDictionary * response, NSError * error))block;
- (void) getUserPractitionerForId:(NSString*)practitionerId atPage:(NSString*)pageNum maxResult:(NSString *)maxResult completion:(void (^)(NSArray * data, NSString *total, NSError * error))block;
- (void) saveUserPractitionerForId:(NSString*)practitionerId withParams:(NSDictionary*)params completion:(void (^)(NSDictionary * response, NSError * error))block;
- (void) addUserPractitionerWithUserId:(NSString*)userId andPrestataireId:(NSString*)prestataireId andParams:(NSMutableDictionary*)params completion:(void (^)(NSDictionary * data, NSError * error))block;
- (void) deleteUserPractitionerForId:(NSString*)practitionerId completion:(void (^)(NSDictionary * response, NSError * error))block;

#pragma mark - Practitien - Beneficiaire

- (void) getPractitionerById:(NSString*)practitionerId completion:(void (^)(NSDictionary * data, NSError * error))block;

@end
