//
//  RXEdition.h
//  rivenx
//
//  Created by Jean-Francois Roy on 02/02/2008.
//  Copyright 2008 MacStorm. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MHKKit/MHKKit.h>

@class RXEditionProxy;


@interface RXEdition : NSObject {
    // should not be modified through KVC
    NSString* key;
    NSString* name;
    
    NSArray* discs;
    NSArray* installDirectives;
    NSDictionary* directories;
    
    NSDictionary* patchArchives;
    
    NSString* userBase;
    NSString* userDataBase;
    
    NSDictionary* stackDescriptors;
    
    NSMutableArray* openArchives;
    
@private
    NSMutableDictionary* _userData;
    NSDictionary* _descriptor;
    BOOL _mustInstall;
}

- (id)initWithDescriptor:(NSDictionary*)descriptor;

- (RXEditionProxy*)proxy;

- (NSMutableDictionary*)userData;
- (BOOL)writeUserData:(NSError**)error;

- (BOOL)mustBeInstalled;
- (BOOL)isInstalled;

- (BOOL)canBecomeCurrent;

- (NSString*)searchForExtrasArchiveInMountPath:(NSString*)path;
- (BOOL)isValidMountPath:(NSString*)path;

@end
