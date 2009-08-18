//
//  RXStack.m
//  rivenx
//
//  Created by Jean-Francois Roy on 30/08/2005.
//  Copyright 2005 MacStorm. All rights reserved.
//

#import <MHKKit/MHKKit.h>

#import "RXStack.h"
#import "RXCardDescriptor.h"

#import "RXWorldProtocol.h"
#import "RXEditionManager.h"

static NSArray* _loadNAMEResourceWithID(MHKArchive* archive, uint16_t resourceID) {
    NSData* nameData = [archive dataWithResourceType:@"NAME" ID:resourceID];
    if (!nameData)
        return nil;
    
    uint16_t recordCount = CFSwapInt16BigToHost(*(const uint16_t*)[nameData bytes]);
    NSMutableArray* recordArray = [[NSMutableArray alloc] initWithCapacity:recordCount];
    
    const uint16_t* offsetBase = (uint16_t*)BUFFER_OFFSET([nameData bytes], sizeof(uint16_t));
    const uint8_t* stringBase = (uint8_t*)BUFFER_OFFSET([nameData bytes], sizeof(uint16_t) + (sizeof(uint16_t) * 2 * recordCount));
    
    for (uint16_t currentRecordIndex = 0; currentRecordIndex < recordCount; currentRecordIndex++) {
        uint16_t recordOffset = CFSwapInt16BigToHost(offsetBase[currentRecordIndex]);
        const unsigned char* entryBase = (const unsigned char*)stringBase + recordOffset;
        size_t recordLength = strlen((const char*)entryBase);
        
        // check for leading and closing 0xbd
        if (*entryBase == 0xbd) {
            entryBase++;
            recordLength--;
        }
        
        if (*(entryBase + recordLength - 1) == 0xbd)
            recordLength--;
        
        NSString* record = [[NSString alloc] initWithBytes:entryBase length:recordLength encoding:NSASCIIStringEncoding];
        [recordArray addObject:record];
        [record release];
    }
    
    return recordArray;
}


@interface RXStack (RXStackPrivate)
- (void)_load;
- (void)_tearDown;
@end

@implementation RXStack

// disable automatic KVC
+ (BOOL)accessInstanceVariablesDirectly {
    return NO;
}

- (id)init {
    [self doesNotRecognizeSelector:_cmd];
    [self release];
    return nil;
}

- (id)initWithStackDescriptor:(NSDictionary*)descriptor key:(NSString*)key error:(NSError**)error {
    self = [super init];
    if (!self)
        return nil;
    
    // check that we have a descriptor object
    if (!descriptor)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Descriptor dictionary cannot be nil." userInfo:nil];
    
    _entryCardID = [[descriptor objectForKey:@"Entry"] unsignedShortValue];
    
    // check that we have a key object
    if (!key)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Key string cannot be nil." userInfo:nil];
    _key = [key copy];
    
    // allocate the archives arrays
    _dataArchives = [[NSMutableArray alloc] initWithCapacity:3];
    _soundArchives = [[NSMutableArray alloc] initWithCapacity:1];
    
    // get the data archives list
    id dataArchives = [descriptor objectForKey:@"Data Archives"];
    if (!dataArchives)
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Descriptor dictionary does not contain data archives information." userInfo:nil];
    
    // get the sound archives list
    id soundArchives = [descriptor objectForKey:@"Sound Archives"];
    if (!soundArchives)
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Descriptor dictionary does not contain sound archives information." userInfo:nil];
    
    // get the edition manager
    RXEditionManager* sem = [RXEditionManager sharedEditionManager];
    
    // load up any patch archives first
    NSArray* patch_archives = [sem dataPatchArchivesForStackKey:_key error:error];
    if (!patch_archives) {
        [self release];
        return nil;
    }
    [_dataArchives addObjectsFromArray:patch_archives];
    
    // load the data archives
    if ([dataArchives isKindOfClass:[NSString class]]) {
        // only one archive
        MHKArchive* anArchive = [sem dataArchiveWithFilename:dataArchives stackKey:_key error:error];
        if (!anArchive) {
            [self release];
            return nil;
        }
        [_dataArchives addObject:anArchive];
    } else if ([dataArchives isKindOfClass:[NSArray class]]) {
        // enumerate the archives
        NSEnumerator* archivesEnum = [dataArchives objectEnumerator];
        NSString* anArchiveName = nil;
        while ((anArchiveName = [archivesEnum nextObject])) {
            MHKArchive* anArchive = [sem dataArchiveWithFilename:anArchiveName stackKey:_key error:error];
            if (!anArchive) {
                [self release];
                return nil;
            }
            [_dataArchives addObject:anArchive];
        }
    } else
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Data Archives object has an invalid type." userInfo:nil];
    
    // load the sound archives
    if ([soundArchives isKindOfClass:[NSString class]]) {
        MHKArchive* anArchive = [sem soundArchiveWithFilename:soundArchives stackKey:_key error:error];
        if (!anArchive) {
            [self release];
            return nil;
        }
        [_soundArchives addObject:anArchive];
    } else if ([soundArchives isKindOfClass:[NSArray class]]) {
        NSEnumerator* archivesEnum = [soundArchives objectEnumerator];
        NSString* anArchiveName = nil;
        while ((anArchiveName = [archivesEnum nextObject])) {
            MHKArchive* anArchive = [sem soundArchiveWithFilename:anArchiveName stackKey:_key error:error];
            if (!anArchive) {
                [self release];
                return nil;
            }
            [_soundArchives addObject:anArchive];
        }
    } else
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Sound Archives object has an invalid type." userInfo:nil];
    
    // load me up, baby
    [self _load];
    
    return self;
}

- (void)_load {
    MHKArchive* masterDataArchive = [_dataArchives lastObject];
    
    // global stack data
    _cardNames = _loadNAMEResourceWithID(masterDataArchive, 1);
    _hotspotNames = _loadNAMEResourceWithID(masterDataArchive, 2);
    _externalNames = _loadNAMEResourceWithID(masterDataArchive, 3);
    _varNames = _loadNAMEResourceWithID(masterDataArchive, 4);
    _stackNames = _loadNAMEResourceWithID(masterDataArchive, 5);
    
    // rmap data
    NSDictionary* rmapDescriptor = [[masterDataArchive valueForKey:@"RMAP"] objectAtIndex:0];
    uint16_t remapID = [[rmapDescriptor objectForKey:@"ID"] unsignedShortValue];
    _rmapData = [[masterDataArchive dataWithResourceType:@"RMAP" ID:remapID] retain];
    
#if defined(DEBUG)
    RXOLog2(kRXLoggingEngine, kRXLoggingLevelDebug, @"stack entry card is %d", _entryCardID);
#endif
}

- (void)_tearDown {
#if defined(DEBUG)
    RXOLog(@"tearing down");
#endif
    
    // release a bunch of objects
    [_cardNames release]; _cardNames = nil;
    [_hotspotNames release]; _hotspotNames = nil;
    [_externalNames release]; _externalNames = nil;
    [_varNames release]; _varNames = nil;
    [_stackNames release]; _stackNames = nil;
    [_rmapData release]; _rmapData = nil;
    
    [_soundArchives release]; _soundArchives = nil;
    [_dataArchives release]; _dataArchives = nil;
}

- (void)dealloc {
#if defined(DEBUG)
    RXOLog(@"deallocating");
#endif
    
    // tear done before we deallocate
    [self _tearDown];
    
    [_key release];
    
    [super dealloc];
}

- (NSString*)description {
    return [NSString stringWithFormat: @"%@{%@}", [super description], _key];
}

- (NSString*)debugName {
    return _key;
}

#pragma mark -

- (NSString*)key {
    return _key;
}

- (uint16_t)entryCardID {
    return _entryCardID;
}

- (NSUInteger)cardCount {
    NSUInteger count = 0;
    NSEnumerator* enumerator = [_dataArchives objectEnumerator];
    MHKArchive* archive;
    while ((archive = [enumerator nextObject]))
        count += [[archive valueForKeyPath:@"CARD.@count"] intValue];
    return count;
}

#pragma mark -

- (NSString*)cardNameAtIndex:(uint32_t)index {
    return (_cardNames) ? [_cardNames objectAtIndex:index] : nil;
}

- (NSString*)hotspotNameAtIndex:(uint32_t)index {
    return (_hotspotNames) ? [_hotspotNames objectAtIndex:index] : nil;
}

- (NSString*)externalNameAtIndex:(uint32_t)index {
    return (_externalNames) ? [_externalNames objectAtIndex:index] : nil;
}

- (NSString*)varNameAtIndex:(uint32_t)index {
    return (_varNames) ? [_varNames objectAtIndex:index] : nil;
}

- (NSString*)stackNameAtIndex:(uint32_t)index {
    return (_stackNames) ? [_stackNames objectAtIndex:index] : nil;
}

- (uint16_t)cardIDFromRMAPCode:(uint32_t)code {
    uint32_t* rmap_data = (uint32_t*)[_rmapData bytes];
    uint32_t* rmap_end = (uint32_t*)((uint8_t*)[_rmapData bytes] + [_rmapData length]);
    uint16_t card_id = 0;
#if defined(__LITTLE_ENDIAN__)
    code = CFSwapInt32(code);
#endif
    while (*(rmap_data + card_id) != code && (rmap_data + card_id) < rmap_end)
        card_id++;
    if (rmap_data == rmap_end)
        return 0;
    return card_id;
}

- (uint32_t)cardRMAPCodeFromID:(uint16_t)card_id {
    uint32_t* rmap_data = (uint32_t*)[_rmapData bytes];
    return CFSwapInt32BigToHost(rmap_data[card_id]);
}

- (id <MHKAudioDecompression>)audioDecompressorWithID:(uint16_t)soundID {
    id <MHKAudioDecompression> decompressor = nil;
    
    NSEnumerator* enumerator = [_soundArchives objectEnumerator];
    MHKArchive* archive;
    while ((archive = [enumerator nextObject])) {
        decompressor = [archive decompressorWithSoundID:soundID error:NULL];
        if (decompressor)
            break;
    }
    return decompressor;
}

- (id <MHKAudioDecompression>)audioDecompressorWithDataID:(uint16_t)soundID {
    id <MHKAudioDecompression> decompressor = nil;
    
    NSEnumerator* enumerator = [_dataArchives objectEnumerator];
    MHKArchive* archive;
    while ((archive = [enumerator nextObject])) {
        decompressor = [archive decompressorWithSoundID:soundID error:NULL];
        if (decompressor)
            break;
    }
    return decompressor;
}

- (uint16_t)dataSoundIDForName:(NSString*)sound_name {
    NSEnumerator* enumerator = [_dataArchives objectEnumerator];
    MHKArchive* archive;
    while ((archive = [enumerator nextObject])) {
        NSDictionary* desc = [archive resourceDescriptorWithResourceType:@"tWAV" name:sound_name];
        if (desc)
            return [[desc objectForKey:@"ID"] unsignedShortValue];
    }
    return 0;
}

- (MHKFileHandle*)fileWithResourceType:(NSString*)type ID:(uint16_t)ID {
    NSEnumerator* enumerator = [_dataArchives objectEnumerator];
    MHKArchive* archive;
    while ((archive = [enumerator nextObject])) {
        MHKFileHandle* file = [archive openResourceWithResourceType:type ID:ID];
        if (file)
            return file;
    }
    
    return nil;
}

- (NSData*)dataWithResourceType:(NSString*)type ID:(uint16_t)ID {
    MHKFileHandle* file = [self fileWithResourceType:type ID:ID];
    if (file)
        return [file readDataToEndOfFile:NULL];
    return nil;
}

@end
