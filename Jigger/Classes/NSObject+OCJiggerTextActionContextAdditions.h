//
//  NSObject+OCJiggerTextActionContextAdditions.h
//  Jigger.sugar
//
//  Created by Ian Beck on 12/14/10.
//  Copyright 2010 One Crayon. MIT license.
//

#import <Foundation/Foundation.h>


@interface NSObject (OCJiggerTextActionContextAdditions)

- (NSString *)getWordAtCursor:(NSUInteger)cursor range:(NSRange *)range;
- (NSString *)getWordAtCursor:(NSUInteger)cursor allowExtraCharacters:(NSCharacterSet *)extraChars range:(NSRange *)range;

@end
