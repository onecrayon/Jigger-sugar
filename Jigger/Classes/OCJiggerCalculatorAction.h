//
//  OCJiggerCalculatorAction.h
//  Jigger.sugar
//
//  Created by Ian Beck on 04/26/12.
//  Copyright 2012 One Crayon. MIT license.
//

#import <Foundation/Foundation.h>
#import <MRRegularExpressionAdditions.h>


@interface OCJiggerCalculatorAction : NSObject <NSTokenFieldDelegate> {
@private
	MRRegularExpression *singleNumberRE;
	MRRegularExpression *selNumberRE;
	NSMutableArray *targetRanges;
	id myContext;
	NSWindow *customSheet;
	NSTokenField *calcField;
}

@property(retain) IBOutlet NSWindow *customSheet;
@property(retain) IBOutlet NSTokenField *calcField;

- (IBAction) doSubmitSheet:(id)sender;
- (IBAction) cancel:(id)sender;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@end
