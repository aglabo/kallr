// src: lib/__tests__/unit/errors.unit.spec.dart
// @(#) : unit tests for the exception types and Hresult codes in errors.dart
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/errors.dart';

// helper
import 'package:w1_w7_verify/environment/notification_environment.dart';

/// Attempt count passed to DuplicateTagException.
const int _attempts = 5;

/// Message passed to UsageException and StorageException.
const String _message = 'bad input';

/// Reason of a registry failure that has a Win32 error (RegistryException normal case).
const String _accessDeniedReason = 'access denied';

/// Win32 error code ERROR_ACCESS_DENIED (RegistryException normal case).
const int _accessDeniedCode = 5;

/// Reason of a registry failure that is not an OS error (RegistryException edge case).
const String _unknownSettingReason = 'unknown notification setting: 99';

/// Reason carried by the failed availability in the toString case.
const String _reason = 'not registered';

/// Failed availability with a reason (UnavailableException cases).
const Availability _unavailable = Availability(
  registered: false,
  displayNameSet: false,
  ok: false,
  reason: _reason,
);

/// Failed availability without a reason (UnavailableException edge case).
const Availability _unavailableWithoutReason = Availability(
  registered: false,
  displayNameSet: false,
  ok: false,
);

/// Tests for the exception types and Hresult codes of errors.dart:
/// toString formats, retained values and the Exception interface.
void main() {
  group('T-WDV-ERR: errors', () {
    /// DuplicateTagException: message format, retained value, interface.
    group('DuplicateTagException', () {
      test('[Normal] T-WDV-ERR-01: toString は試行回数を含む書式である', () {
        expect(
          const DuplicateTagException(attempts: _attempts).toString(),
          'DuplicateTagException: Tag was duplicated in all 5 attempts',
        );
      });

      test('[Normal] T-WDV-ERR-02: Exception を実装し attempts を保持する', () {
        const error = DuplicateTagException(attempts: _attempts);
        expect(error, isA<Exception>());
        expect(error.attempts, _attempts);
      });
    });

    /// UsageException: message format, retained value, interface.
    group('UsageException', () {
      test('[Normal] T-WDV-ERR-03: toString は型名とメッセージである', () {
        expect(
          const UsageException(_message).toString(),
          'UsageException: bad input',
        );
      });

      test('[Normal] T-WDV-ERR-04: Exception を実装し message を保持する', () {
        const error = UsageException(_message);
        expect(error, isA<Exception>());
        expect(error.message, _message);
      });
    });

    /// StorageException: message format, retained value, interface.
    group('StorageException', () {
      test('[Normal] T-WDV-ERR-05: toString は型名とメッセージである', () {
        expect(
          const StorageException(_message).toString(),
          'StorageException: bad input',
        );
      });

      test('[Normal] T-WDV-ERR-06: Exception を実装し message を保持する', () {
        const error = StorageException(_message);
        expect(error, isA<Exception>());
        expect(error.message, _message);
      });
    });

    /// RegistryException: toString with and without a Win32 code.
    group('RegistryException', () {
      test('[Normal] T-WDV-ERR-14: toString は理由と Win32 コードを含む', () {
        expect(
          const RegistryException(
            _accessDeniedReason,
            win32Code: _accessDeniedCode,
          ).toString(),
          allOf(contains(_accessDeniedReason), contains('Win32 code 5')),
        );
      });

      test('[Edge] T-WDV-ERR-15: コードが無ければ toString は Win32 コードを含まない', () {
        expect(
          const RegistryException(_unknownSettingReason).toString(),
          allOf(contains(_unknownSettingReason), isNot(contains('Win32 code'))),
        );
      });
    });

    /// Hresult: the HRESULT code values.
    group('Hresult', () {
      test('[Normal] T-WDV-ERR-07: invalidArgument は 0x80070057 である', () {
        expect(Hresult.invalidArgument, 0x80070057);
      });

      test('[Normal] T-WDV-ERR-08: tooManyToasts は 0x80070718 である', () {
        expect(Hresult.tooManyToasts, 0x80070718);
      });
    });

    /// ScheduleException: message format, retained value, interface.
    group('ScheduleException', () {
      test('[Normal] T-WDV-ERR-09: toString は小文字 16 進の HRESULT を含む', () {
        expect(
          const ScheduleException(Hresult.invalidArgument).toString(),
          'ScheduleException: 0x80070057',
        );
      });

      test('[Normal] T-WDV-ERR-10: Exception を実装し hresult を保持する', () {
        const error = ScheduleException(Hresult.tooManyToasts);
        expect(error, isA<Exception>());
        expect(error.hresult, Hresult.tooManyToasts);
      });
    });

    /// UnavailableException: message format, retained value, interface.
    group('UnavailableException', () {
      test('[Normal] T-WDV-ERR-11: toString は availability の reason を含む', () {
        expect(
          const UnavailableException(_unavailable).toString(),
          'UnavailableException: not registered',
        );
      });

      test('[Normal] T-WDV-ERR-12: Exception を実装し availability を保持する', () {
        const error = UnavailableException(_unavailable);
        expect(error, isA<Exception>());
        expect(error.availability, same(_unavailable));
      });

      test('[Edge] T-WDV-ERR-13: reason が null のとき toString は文字列 null を含む', () {
        expect(
          const UnavailableException(_unavailableWithoutReason).toString(),
          'UnavailableException: null',
        );
      });
    });
  });
}
