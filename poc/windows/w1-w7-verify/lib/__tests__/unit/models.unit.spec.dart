// src: lib/__tests__/unit/models.unit.spec.dart
// @(#) : unit tests for the shared constants in models.dart
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/models.dart';

/// Upper limit of the Group length (TAG-R-004).
const int _groupMaxLength = 64;

/// Tests for kGroup: fixed value and length limit.
void main() {
  group('T-WDV-MDL: kGroup', () {
    group('When: 値を参照する', () {
      test('[Normal] T-WDV-MDL-01: kGroup は kallr で、上限 64 文字以下である', () {
        expect(kGroup, 'kallr');
        expect(kGroup.length, lessThanOrEqualTo(_groupMaxLength));
      });
    });
  });
}
