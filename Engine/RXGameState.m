//
//	RXGameState.m
//	rivenx
//
//	Created by Jean-Francois Roy on 02/11/2007.
//	Copyright 2007 MacStorm. All rights reserved.
//

#import "RXGameState.h"
#import "RXEditionManager.h"

static const int RX_GAME_STATE_CURRENT_VERSION = 1;


@implementation RXGameState

// disable automatic KVC
+ (BOOL)accessInstanceVariablesDirectly {
	return NO;
}

+ (RXGameState*)gameStateWithURL:(NSURL*)url error:(NSError**)error {
	// read the data in
	NSData* archive = [NSData dataWithContentsOfURL:url options:(NSMappedRead | NSUncachedRead) error:error];
	if (!archive) {
		[self release];
		return nil;
	}
	
	// use a keyed unarchiver to unfreeze a new game state object
	RXGameState* gameState =  [NSKeyedUnarchiver unarchiveObjectWithData:archive];
	
	// set the write URL on the game state to indicate it has an existing location on the file system
	if (gameState)
		gameState->_URL = [url retain];
	return gameState;
}

- (void)_initRandomValues {
	[self setShort:-2 forKey:@"aDomeCombo"];
	[self setShort:-2 forKey:@"pCorrectOrder"];
	[self setShort:-2 forKey:@"tCorrectOrder"];
	[self setShort:-2 forKey:@"jIconCorrectOrder"];
	[self setShort:-2 forKey:@"pCorrectOrder"];
}

- (id)init {
	[self doesNotRecognizeSelector:_cmd];
	[self release];
	return nil;
}

- (id)initWithEdition:(RXEdition*)edition {
	self = [super init];
	if (!self)
		return nil;
	
	_accessLock = [NSRecursiveLock new];
	
	if (edition == nil) {
		[self release];
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"edition must not be nil" userInfo:nil];
	}
	
	NSError* error = nil;
	NSData* defaultVarData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"GameVariables" ofType:@"plist"] options:0 error:&error];
	if (!defaultVarData) {
		[self release];
		@throw [NSException exceptionWithName:@"RXMissingDefaultEngineVariablesException" reason:@"Unable to find GameVariables.plist." userInfo:[NSDictionary dictionaryWithObject:error forKey:NSUnderlyingErrorKey]];
	}
	
	NSString* errorString = nil;
	_variables = [[NSPropertyListSerialization propertyListFromData:defaultVarData mutabilityOption:NSPropertyListMutableContainers format:NULL errorDescription:&errorString] retain];
	if (!_variables) {
		[self release];
		@throw [NSException exceptionWithName:@"RXInvalidDefaultEngineVariablesException" reason:@"Unable to load the default engine variables." userInfo:[NSDictionary dictionaryWithObject:errorString forKey:@"RXErrorString"]];
	}
	[errorString release];
	
	_edition = [edition retain];
	
	// a certain part of the game state is random generated; defer that work to another dedicated method
	[self _initRandomValues];
	
	// no URL for new game states
	_URL = nil;
	
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder {
	self = [super init];
	if (!self)
		return nil;
	
	_accessLock = [NSRecursiveLock new];

	if (![decoder containsValueForKey:@"VERSION"]) {
		[self release];
		return nil;
	}
	int32_t version = [decoder decodeInt32ForKey:@"VERSION"];
	
	switch (version) {
		case 1:
			if (![decoder containsValueForKey:@"returnCard"]) {
				[self release];
				@throw [NSException exceptionWithName:@"RXInvalidGameStateArchive" reason:@"Riven X does not understand this save file. It may be corrupted or may not be a Riven X save file at all." userInfo:nil];
			}
			_returnCard = [[decoder decodeObjectForKey:@"returnCard"] retain];
		
		case 0:
			if (![decoder containsValueForKey:@"editionKey"]) {
				[self release];
				@throw [NSException exceptionWithName:@"RXInvalidGameStateArchive" reason:@"Riven X does not understand this save file. It may be corrupted or may not be a Riven X save file at all." userInfo:nil];
			}
			NSString* editionKey = [decoder decodeObjectForKey:@"editionKey"];
			_edition = [[[RXEditionManager sharedEditionManager] editionForKey:editionKey] retain];
			if (!_edition) {
				[self release];
				@throw [NSException exceptionWithName:@"RXUnknownEditionKeyException" reason:@"Riven X was unable to find the edition for this save file." userInfo:nil];
			}
			
			if (![decoder containsValueForKey:@"currentCard"]) {
				[self release];
				@throw [NSException exceptionWithName:@"RXInvalidGameStateArchive" reason:@"Riven X does not understand this save file. It may be corrupted or may not be a Riven X save file at all." userInfo:nil];
			}
			_currentCard = [[decoder decodeObjectForKey:@"currentCard"] retain];

			if (![decoder containsValueForKey:@"variables"]) {
				[self release];
				@throw [NSException exceptionWithName:@"RXInvalidGameStateArchive" reason:@"Riven X does not understand this save file. It may be corrupted or may not be a Riven X save file at all." userInfo:nil];
			}
			_variables = [[decoder decodeObjectForKey:@"variables"] retain];
			
			break;
		
		default:
			@throw [NSException exceptionWithName:@"RXInvalidGameStateArchive" reason:@"Riven X does not understand this save file. It may be corrupted or may not be a Riven X save file at all." userInfo:nil];
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder {
	if (![encoder allowsKeyedCoding])
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"RXGameState only supports keyed archiving." userInfo:nil];
	
	[_accessLock lock];
	
	[encoder encodeInt32:RX_GAME_STATE_CURRENT_VERSION forKey:@"VERSION"];
	
	[encoder encodeObject:[_edition valueForKey:@"key"] forKey:@"editionKey"];
	[encoder encodeObject:_currentCard forKey:@"currentCard"];
	[encoder encodeObject:_returnCard forKey:@"returnCard"];
	[encoder encodeObject:_variables forKey:@"variables"];
	
	[_accessLock unlock];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_edition release];
	[_variables release];
	[_currentCard release];
	[_returnCard release];
	[_URL release];
	[_accessLock release];
	
	[super dealloc];
}

- (void)dump {
	RXOLog(@"dumping\n%@", _variables);
}

- (NSURL*)URL {
	return _URL;
}

- (BOOL)writeToURL:(NSURL*)url error:(NSError**)error {
	// serialize ourselves as data
	NSData* gameStateData = [NSKeyedArchiver archivedDataWithRootObject:self];
	if (!gameStateData)
		ReturnValueWithError(NO, @"RXErrorDomain", 0, nil, error);
	
	// write the data
	BOOL success = [gameStateData writeToURL:url options:NSAtomicWrite error:error];
	
	// if we were successful, keep the URL around
	if (success) {
		[_URL release];
		_URL = [url retain];
	}
	
	return success;
}

- (uint16_t)unsignedShortForKey:(NSString*)key {
	key = [key lowercaseString];
	uint16_t v = 0;
	
	[_accessLock lock];
	NSNumber* n = [_variables objectForKey:key];
	if (n)
		v = [n unsignedShortValue];
	else
		[self setUnsignedShort:0 forKey:key];
	[_accessLock unlock];
	
	return v;
}

- (int16_t)shortForKey:(NSString*)key {
	key = [key lowercaseString];
	int16_t v = 0;
	
	[_accessLock lock];
	NSNumber* n = [_variables objectForKey:key];
	if (n)
		v = [n shortValue];
	else
		[self setShort:0 forKey:key];
	[_accessLock unlock];
	
	return v;
}

- (void)setUnsignedShort:(uint16_t)value forKey:(NSString*)key {
	key = [key lowercaseString];
#if defined(DEBUG)
	RXOLog(@"setting variable %@ to %hu", key, value);
#endif
	[self willChangeValueForKey:key];
	[_accessLock lock];
	[_variables setObject:[NSNumber numberWithUnsignedShort:value] forKey:key];
	[_accessLock unlock];
	[self didChangeValueForKey:key];
}

- (void)setShort:(int16_t)value forKey:(NSString*)key {
	key = [key lowercaseString];
#if defined(DEBUG)
	RXOLog(@"setting variable %@ to %hd", key, value);
#endif
	[self willChangeValueForKey:key];
	[_accessLock lock];
	[_variables setObject:[NSNumber numberWithUnsignedShort:value] forKey:key];
	[_accessLock unlock];
	[self didChangeValueForKey:key];
}

- (BOOL)isKeySet:(NSString*)key {
	key = [key lowercaseString];
	[_accessLock lock];
	BOOL b = ([_variables objectForKey:key]) ? YES : NO;
	[_accessLock unlock];
	return b;
}

- (RXSimpleCardDescriptor*)currentCard {
	return _currentCard;
}

- (void)setCurrentCard:(RXSimpleCardDescriptor*)descriptor {
	[_currentCard release];
	_currentCard = [descriptor retain];
	
	[self setUnsignedShort:descriptor->cardID forKey:@"currentcardid"];
	[self setUnsignedShort:[[[[_edition valueForKeyPath:@"stackDescriptors"] objectForKey:descriptor->parentName] objectForKey:@"ID"] unsignedShortValue] forKey:@"currentstackid"];
}

- (RXSimpleCardDescriptor*)returnCard {
	return _returnCard;
}

- (void)setReturnCard:(RXSimpleCardDescriptor*)descriptor {
	[_returnCard release];
	_returnCard = [descriptor retain];
	
	[self setUnsignedShort:descriptor->cardID forKey:@"returncardid"];
	[self setUnsignedShort:[[[[_edition valueForKeyPath:@"stackDescriptors"] objectForKey:descriptor->parentName] objectForKey:@"ID"] unsignedShortValue] forKey:@"returnstackid"];
}

@end
