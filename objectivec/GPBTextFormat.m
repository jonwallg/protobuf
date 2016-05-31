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

static void MergeField(GPBMessage *self, NSScanner *scanner);

static void MergeFieldValues(GPBMessage *self, GPBFieldDescriptor *field, NSScanner *scanner);

static void MergeFieldValue(GPBMessage *self, GPBFieldDescriptor *field, NSScanner *scanner);

static void Error(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

static id ObtainArray(GPBMessage *self, GPBFieldDescriptor *field);

static BOOL ScanIdentifierIntoString(NSScanner *scanner, NSString **string);

BOOL GPBMergeFromTextFormatString(GPBMessage *self, NSString *textFormat,
                                  BOOL allowUnknownFields, NSError **errorPtr) {
  NSScanner *scanner = [[[NSScanner alloc] initWithString:textFormat] autorelease];
  scanner.charactersToBeSkipped = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  @try {
    while (![scanner isAtEnd]) {
      MergeField(self, scanner);
    }
  } @catch (NSException *exception) {
    if (errorPtr) {
      *errorPtr = [NSError errorWithDomain:@"foo"
                                      code:1
                                  userInfo:@{ NSLocalizedDescriptionKey : exception.reason}];
      return NO;
    }
  }
  return YES;
}

static void MergeField(GPBMessage *self, NSScanner *scanner) {
  if ([scanner scanString:@"[" intoString:NULL]) {
    // TODO: extension
  } else {
    NSString *name;
    if (![scanner gpb_scanIdentifierIntoString:&name]) {
      Error(@"No identifier");
    }
    GPBDescriptor *descriptor = [self descriptor];
    GPBFieldDescriptor *fieldDescriptor = [descriptor fieldWithTextFormatName:name];
    if (!fieldDescriptor) {
      Error(@"No field with name: %@", name);
    }
    if (![scanner scanString:@":" intoString:NULL]) {
      Error(@"No colon");
    }
    MergeFieldValues(self, fieldDescriptor, self);
  }
}

void MergeFieldValues(GPBMessage *self, GPBFieldDescriptor *field, NSScanner *scanner) {
  if (field.fieldType == GPBFieldTypeRepeated && [scanner scanString:@"[" intoString:NULL]) {
    while (true) {
      MergeFieldValue(self, field, scanner);
      if ([scanner scanString:@"]" intoString:NULL]) {
        // End of list.
        break;
      }
      if (![scanner scanString:@"," intoString:NULL]) {
        Error(@"No comma");
      }
    }
  } else {
    MergeFieldValue(self, field, scanner);
  }
}

void MergeFieldValue(GPBMessage *self, GPBFieldDescriptor *field, NSScanner *scanner) {
  switch (field.dataType) {
    case GPBDataTypeBool:
      // TODO
      break;
    case GPBDataTypeFixed32:
    case GPBDataTypeUInt32: {
      unsigned long long longValue;
      if (![scanner scanUnsignedLongLong:&longValue]) {
        Error(@"Cannot scan unsigned int value");
      }
      assert(longValue < UINT32_MAX);
      uint32_t value = (uint32_t)longValue;
      if (field.fieldType == GPBFieldTypeRepeated) {
        GPBUInt32Array *array = ObtainArray(self, field);
        [array addValue:value];
      } else {
        GPBSetMessageUInt32Field(self, field, value);
      }
      break;
    }
    case GPBDataTypeSFixed32:
    case GPBDataTypeSInt32:
    case GPBDataTypeInt32: {
      int32_t value;
      if (![scanner scanInt:&value]) {
        Error(@"Cannot scan int value");
      }
      if (field.fieldType == GPBFieldTypeRepeated) {
        GPBInt32Array *array = ObtainArray(self, field);
        [array addValue:value];
      } else {
        GPBSetMessageInt32Field(self, field, value);
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
        Error(@"No start quote");
      }
      NSString *value = nil;
      [scanner scanUpToString:@"\"" intoString:&value];
      if (![scanner scanString:@"\"" intoString:NULL]) {
        Error(@"No end quote");
      }
      if (field.fieldType == GPBFieldTypeRepeated) {
        NSMutableArray *array = ObtainArray(self, field);
        [array addObject:value];
      } else {
        GPBSetMessageStringField(self, field, value);
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
        Error(@"No start token for submessage: %@", [field textFormatName]);
      }
      GPBMessage *submessage = [field.msgClass message];
      MergeField(submessage, scanner);
      if (field.fieldType == GPBFieldTypeRepeated) {
        NSMutableArray *array = ObtainArray(self, field);
        [array addObject:submessage];
      } else {
        GPBSetMessageMessageField(self, field, submessage);
      }
      if (![scanner scanString:endToken intoString:NULL]) {
        Error(@"No end token for submessage %@: %@", [field textFormatName], submessage);
      }
      break;
    }
    case GPBDataTypeEnum: {
      int32_t rawValue;
      if (![scanner scanInt:&rawValue]) {
        NSString *stringValue;
        if (!ScanIdentifierIntoString(scanner, &stringValue)) {
          Error(@"No enum value");
        }
        if (![field.enumDescriptor getValue:&rawValue forEnumTextFormatName:stringValue]) {
          Error(@"Invalid enum value: %@", stringValue);
        }
      }
      if (!field.enumDescriptor.enumVerifier(rawValue)) {
        Error(@"Invalid enum value: %d", rawValue);
      }
      if (field.fieldType == GPBFieldTypeRepeated) {
        GPBEnumArray *array = ObtainArray(self, field);
        [array addRawValue:rawValue];
      } else {
        GPBSetMessageEnumField(self, field, rawValue);
      }
      break;
    }
    case GPBDataTypeGroup:
      // TODO
      break;
  }
}

id ObtainArray(GPBMessage *self, GPBFieldDescriptor *field) {
  id result = GPBGetObjectIvarWithFieldNoAutocreate(self, field);
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
    GPBSetMessageRepeatedField(self, field, result);
  }
  return result;
}

BOOL ScanIdentifierIntoString(NSScanner *scanner, NSString **string) {
  static NSCharacterSet *identifierCharacters = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableCharacterSet *mutable = [NSMutableCharacterSet alphanumericCharacterSet];
    [mutable addCharactersInString:@"_."];
    identifierCharacters = [mutable copy];
  });
  return [scanner scanCharactersFromSet:identifierCharacters intoString:string];
}

void Error(NSString *format, ...) {
  va_list args;
  va_start(args, format);
  [NSException raise:NSParseErrorException format:format arguments:args];
  va_end(args);
}
