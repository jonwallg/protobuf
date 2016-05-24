// Protocol Buffers - Google's data interchange format
// Copyright 2015 Google Inc.  All rights reserved.
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

#import "GPBTestUtilities.h"
#import "GPBTextFormat.h"

#import "google/protobuf/Unittest.pbobjc.h"

@interface TextFormatTest : GPBTestCase
@end

@implementation TextFormatTest

- (void)parseText:(NSString *)text message:(GPBMessage *)message {
  NSError *error = nil;
  [GPBTextFormat mergeFromTextFormat:text message:message error:&error];
  XCTAssertNil(error);
}

- (void)testOptionalFields {
  NSArray<NSString *> *lines = @[
    @"optional_int32: 12",
    @"optional_string: \"foo\"",
    @"optional_nested_message: {",
    @" bb: 12",
    @"}",
    @"optional_foreign_message: {",
    @" c: 13",
    @"}",
    @"optional_nested_enum: FOO",
    @"optional_foreign_enum: FOREIGN_FOO",
  ];
  NSString *text = [lines componentsJoinedByString:@"\n"];

  TestAllTypes *msg = [TestAllTypes message];

  [self parseText:text message:msg];
  XCTAssertEqual(msg.optionalInt32, 12);
  XCTAssertEqualObjects(msg.optionalString, @"foo");

  XCTAssertTrue(msg.hasOptionalNestedMessage);
  XCTAssertEqual(msg.optionalNestedMessage.bb, 12);
  XCTAssertTrue(msg.hasOptionalForeignMessage);
  XCTAssertEqual(msg.optionalForeignMessage.c, 13);

  XCTAssertEqual(msg.optionalNestedEnum, TestAllTypes_NestedEnum_Foo);
  XCTAssertEqual(msg.optionalForeignEnum, ForeignEnum_ForeignFoo);
}

- (void)testRepeatedFields {
  NSArray<NSString *> *lines = @[
    @"repeated_int32: -41",
    @"repeated_int32: 42",
    @"repeated_sint32: -7",
    @"repeated_sint32: 7",
    @"repeated_uint32: 8",
    @"repeated_uint32: 9",
    @"repeated_fixed32: 23",
    @"repeated_fixed32: 24",
    @"repeated_string: \"foo\"",
    @"repeated_string: \"bar\"",
    @"repeated_nested_message: {",
    @" bb: 31",
    @"}",
    @"repeated_nested_message: {",
    @" bb: 32",
    @"}",
    @"repeated_foreign_message: {",
    @" c: 51",
    @"}",
    @"repeated_foreign_message: {",
    @" c: 52",
    @"}",
    @"repeated_nested_enum: BAZ",
    @"repeated_nested_enum: FOO",
    @"repeated_foreign_enum: FOREIGN_BAZ",
    @"repeated_foreign_enum: FOREIGN_FOO",
  ];
  NSString *text = [lines componentsJoinedByString:@"\n"];
  TestAllTypes *msg = [TestAllTypes message];
  [self parseText:text message:msg];

  XCTAssertEqual(msg.repeatedInt32Array_Count, 2U);
  XCTAssertEqual([msg.repeatedInt32Array valueAtIndex:0], -41);
  XCTAssertEqual([msg.repeatedInt32Array valueAtIndex:1], 42);

  XCTAssertEqual(msg.repeatedSint32Array_Count, 2U);
  XCTAssertEqual([msg.repeatedSint32Array valueAtIndex:0], -7);
  XCTAssertEqual([msg.repeatedSint32Array valueAtIndex:1], 7);

  XCTAssertEqual(msg.repeatedUint32Array_Count, 2U);
  XCTAssertEqual([msg.repeatedUint32Array valueAtIndex:0], 8U);
  XCTAssertEqual([msg.repeatedUint32Array valueAtIndex:1], 9U);

  XCTAssertEqual(msg.repeatedFixed32Array_Count, 2U);
  XCTAssertEqual([msg.repeatedFixed32Array valueAtIndex:0], 23U);
  XCTAssertEqual([msg.repeatedFixed32Array valueAtIndex:1], 24U);

  XCTAssertEqual(msg.repeatedStringArray_Count, 2U);
  XCTAssertEqualObjects(msg.repeatedStringArray[0], @"foo");
  XCTAssertEqualObjects(msg.repeatedStringArray[1], @"bar");

  XCTAssertEqual(msg.repeatedNestedMessageArray_Count, 2U);
  XCTAssertEqual([msg.repeatedNestedMessageArray[0] bb], 31);
  XCTAssertEqual([msg.repeatedNestedMessageArray[1] bb], 32);

  XCTAssertEqual(msg.repeatedForeignMessageArray_Count, 2U);
  XCTAssertEqual([msg.repeatedForeignMessageArray[0] c], 51);
  XCTAssertEqual([msg.repeatedForeignMessageArray[1] c], 52);

  XCTAssertEqual(msg.repeatedNestedEnumArray_Count, 2U);
  XCTAssertEqual([msg.repeatedNestedEnumArray valueAtIndex:0], TestAllTypes_NestedEnum_Baz);
  XCTAssertEqual([msg.repeatedNestedEnumArray valueAtIndex:1], TestAllTypes_NestedEnum_Foo);

  XCTAssertEqual(msg.repeatedForeignEnumArray_Count, 2U);
  XCTAssertEqual([msg.repeatedForeignEnumArray valueAtIndex:0], ForeignEnum_ForeignBaz);
  XCTAssertEqual([msg.repeatedForeignEnumArray valueAtIndex:1], ForeignEnum_ForeignFoo);
}

- (void)testEnumRawValue {
  NSArray<NSString *> *lines = @[
    @"optional_nested_enum: 3",  // BAZ
    @"optional_foreign_enum: 6",  // FOREIGN_BAZ
  ];
  NSString *text = [lines componentsJoinedByString:@"\n"];
  TestAllTypes *msg = [TestAllTypes message];
  [self parseText:text message:msg];

  XCTAssertEqual(msg.optionalNestedEnum, TestAllTypes_NestedEnum_Baz);
  XCTAssertEqual(msg.optionalForeignEnum, ForeignEnum_ForeignBaz);
}

@end
