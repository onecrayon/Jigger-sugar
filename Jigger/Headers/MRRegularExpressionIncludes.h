//
//  MRRegularExpressionIncludes.h
//  MRRegularExpressions
//

#import <Foundation/Foundation.h>
#import <oniguruma.h>


#define MRRegularExpressionErrorDomain @"MRRegularExpressionErrorDomain"

// Custom type to maintain correct masks in 32/64-bit
typedef OnigOptionType RXUInteger;

// Encoding helpers
#define MRRegularExpressionNSStringEncoding NSUTF16LittleEndianStringEncoding
#define MRRegularExpressionOnigurumaEncoding ONIG_ENCODING_UTF16_LE
#define MRRegularExpressionLengthFromByteRange(startPtr, endPtr) ((NSUInteger)(((endPtr)-(startPtr))/2))
