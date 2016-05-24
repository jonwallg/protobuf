// Protocol Buffers - Google's data interchange format
// Copyright 2008 Google Inc.  All rights reserved.
// https://developers.google.com/protocol-buffers/
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "GPBTextFormat.h"

#import "GPBDescriptor.h"
#import "GPBMessage.h"
#import "GPBUtilities.h"
#import "GPBUtilities_PackagePrivate.h"

@interface NSScanner (GPBTextFormat)
- (BOOL)gpb_scanIdentifierIntoString:(NSString **)s;
@end

@implementation GPBTextFormat

+ (void)error:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2) {
  va_list args;
  va_start(args, format);
  [NSException raise:NSParseErrorException format:format arguments:args];
  va_end(args);
}

+ (void)mergeFromTextFormat:(NSString *)textFormat
                    message:(GPBMessage *)message
                      error:(NSError **)errorPtr {
  NSScanner *scanner = [[[NSScanner alloc] initWithString:textFormat] autorelease];
  scanner.charactersToBeSkipped = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  @try {
    while (![scanner isAtEnd]) {
      [self mergeField:scanner message:message];
    }
  } @catch (NSException *exception) {
    if (errorPtr) {
      *errorPtr = [NSError errorWithDomain:@"foo"
                                      code:1
                                  userInfo:@{ NSLocalizedDescriptionKey : exception.reason}];
    }
  }
}

+ (void)mergeField:(NSScanner *)scanner message:(GPBMessage *)message {
  if ([scanner scanString:@"[" intoString:NULL]) {
    // TODO: extension
  } else {
    NSString *name;
    if (![scanner gpb_scanIdentifierIntoString:&name]) {
      [self error:@"No identifier"];
    }
    GPBDescriptor *descriptor = [message descriptor];
    GPBFieldDescriptor *fieldDescriptor = [descriptor fieldWithTextFormatName:name];
    if (!fieldDescriptor) {
      [self error:@"No field with name: %@", name];
    }

    if (![scanner scanString:@":" intoString:NULL]) {
      [self error:@"No colon"];
    }
    [self mergeFieldValues:scanner message:message field:fieldDescriptor];
  }
}

+ (void)mergeFieldValues:(NSScanner *)scanner
                 message:(GPBMessage *)message
                   field:(GPBFieldDescriptor *)field {
  if (field.fieldType == GPBFieldTypeRepeated && [scanner scanString:@"[" intoString:NULL]) {
    while (true) {
      [self mergeFieldValue:scanner message:message field:field];
      if ([scanner scanString:@"]" intoString:NULL]) {
        // End of list.
        break;
      }
      if (![scanner scanString:@"," intoString:NULL]) {
        [self error:@"No comma"];
      }
    }
  } else {
    [self mergeFieldValue:scanner message:message field:field];
  }
}

+ (id)obtainArrayForMessage:(GPBMessage *)message field:(GPBFieldDescriptor *)field {
  id result = GPBGetObjectIvarWithFieldNoAutocreate(message, field);
  if (!result) {
    switch (field.dataType) {
      case GPBDataTypeBool:
        result = [[[GPBBoolArray alloc] init] autorelease];
        break;
      case GPBDataTypeFixed32:
      case GPBDataTypeUInt32:
        result = [[[GPBUInt32Array alloc] init] autorelease];
        break;
      case GPBDataTypeInt32:
      case GPBDataTypeSFixed32:
      case GPBDataTypeSInt32:
        result = [[[GPBInt32Array alloc] init] autorelease];
        break;
      case GPBDataTypeFixed64:
      case GPBDataTypeUInt64:
        result = [[[GPBUInt64Array alloc] init] autorelease];
        break;
      case GPBDataTypeInt64:
      case GPBDataTypeSFixed64:
      case GPBDataTypeSInt64:
        result = [[[GPBInt64Array alloc] init] autorelease];
        break;
      case GPBDataTypeFloat:
        result = [[[GPBFloatArray alloc] init] autorelease];
        break;
      case GPBDataTypeDouble:
        result = [[[GPBDoubleArray alloc] init] autorelease];
        break;
      case GPBDataTypeEnum: {
        GPBEnumValidationFunc verifier = field.enumDescriptor.enumVerifier;
        result = [[[GPBEnumArray alloc] initWithValidationFunction:verifier] autorelease];
        break;
      }
      case GPBDataTypeBytes:
      case GPBDataTypeGroup:
      case GPBDataTypeMessage:
      case GPBDataTypeString:
        result = [[[NSMutableArray alloc] init] autorelease];
        break;
    }
    GPBSetMessageRepeatedField(message, field, result);
  }
  return result;
}

+ (void)mergeFieldValue:(NSScanner *)scanner
                message:(GPBMessage *)message
                  field:(GPBFieldDescriptor *)field {
  switch (field.dataType) {
    case GPBDataTypeBool:
      // TODO
      break;
    case GPBDataTypeFixed32:
    case GPBDataTypeUInt32: {
      unsigned long long longValue;
      if (![scanner scanUnsignedLongLong:&longValue]) {
        [self error:@"Cannot scan unsigned int value"];
      }
      assert(longValue < UINT32_MAX);
      uint32_t value = (uint32_t)longValue;
      if (field.fieldType == GPBFieldTypeRepeated) {
        GPBUInt32Array *array = [self obtainArrayForMessage:message field:field];
        [array addValue:value];
      } else {
        GPBSetMessageUInt32Field(message, field, value);
      }
      break;
    }
    case GPBDataTypeSFixed32:
    case GPBDataTypeSInt32:
    case GPBDataTypeInt32: {
      int32_t value;
      if (![scanner scanInt:&value]) {
        [self error:@"Cannot scan int value"];
      }
      if (field.fieldType == GPBFieldTypeRepeated) {
        GPBInt32Array *array = [self obtainArrayForMessage:message field:field];
        [array addValue:value];
      } else {
        GPBSetMessageInt32Field(message, field, value);
      }
      break;
    }
    case GPBDataTypeFixed64:
    case GPBDataTypeUInt64: {
      // TODO
      break;
    }
    case GPBDataTypeInt64:
    case GPBDataTypeSFixed64:
    case GPBDataTypeSInt64: {
      // TODO
      break;
    }
    case GPBDataTypeFloat:
      // TODO
      break;
    case GPBDataTypeDouble:
      // TODO
      break;
    case GPBDataTypeBytes:
      // TODO
      break;
    case GPBDataTypeString: {
      if (![scanner scanString:@"\"" intoString:NULL]) {
        [self error:@"No start quote"];
      }
      NSString *value = nil;
      [scanner scanUpToString:@"\"" intoString:&value];
      if (![scanner scanString:@"\"" intoString:NULL]) {
        [self error:@"No end quote"];
      }
      if (field.fieldType == GPBFieldTypeRepeated) {
        NSMutableArray *array = [self obtainArrayForMessage:message field:field];
        [array addObject:value];
      } else {
        GPBSetMessageStringField(message, field, value);
      }
      break;
    }
    case GPBDataTypeMessage: {
      NSString *endToken = nil;
      if ([scanner scanString:@"<" intoString:NULL]) {
        endToken = @">";
      } else if ([scanner scanString:@"{" intoString:NULL]) {
        endToken = @"}";
      } else {
        [self error:@"No start token for submessage: %@", [field textFormatName]];
      }
      GPBMessage *submessage = [field.msgClass message];
      [self mergeField:scanner message:submessage];
      if (field.fieldType == GPBFieldTypeRepeated) {
        NSMutableArray *array = [self obtainArrayForMessage:message field:field];
        [array addObject:submessage];
      } else {
        GPBSetMessageMessageField(message, field, submessage);
      }
      if (![scanner scanString:endToken intoString:NULL]) {
        [self error:@"No end token for submessage %@: %@", [field textFormatName], submessage];
      }
      break;
    }
    case GPBDataTypeEnum: {
      int32_t rawValue;
      if (![scanner scanInt:&rawValue]) {
        NSString *stringValue;
        if (![scanner gpb_scanIdentifierIntoString:&stringValue]) {
          [self error:@"No enum value"];
        }
        if (![field.enumDescriptor getValue:&rawValue forEnumTextFormatName:stringValue]) {
          [self error:@"Invalid enum value: %@", stringValue];
        }
      }
      if (!field.enumDescriptor.enumVerifier(rawValue)) {
        [self error:@"Invalid enum value: %d", rawValue];
      }
      if (field.fieldType == GPBFieldTypeRepeated) {
        GPBEnumArray *array = [self obtainArrayForMessage:message field:field];
        [array addRawValue:rawValue];
      } else {
        GPBSetMessageEnumField(message, field, rawValue);
      }
      break;
    }
    case GPBDataTypeGroup:
      // TODO
      break;
  }
}

@end

@implementation NSScanner (GPBTextFormat)

- (BOOL)gpb_scanIdentifierIntoString:(NSString **)s {
  static NSCharacterSet *identifierCharacters = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableCharacterSet *mutable = [NSMutableCharacterSet alphanumericCharacterSet];
    [mutable addCharactersInString:@"_."];
    identifierCharacters = [mutable copy];
  });
  return [self scanCharactersFromSet:identifierCharacters intoString:s];
}

@end
