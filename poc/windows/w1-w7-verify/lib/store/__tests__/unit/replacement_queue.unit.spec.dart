// src: lib/store/__tests__/unit/replacement_queue.unit.spec.dart
// @(#) : unit tests for SqliteStore.replace (replacement queue)
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'dart:async';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/errors.dart';
import 'package:w1_w7_verify/models.dart';
import 'package:w1_w7_verify/store/sqlite_store.dart';

// internal helpers

/// Tag of the old (current) row used by the replace cases.
const String _oldTag = '20261122090000-a1b2c3d4-0123456789abcdef';

/// Tag of the new (pending) row used by the replace cases.
const String _newTag = '20261122093000-a1b2c3d4-0123456789abcdef';

/// Record of the key (b1, a1) with [tag], [at] and [title]; `registeredAt` is fixed.
MappingRecord _record(String tag, String at, String title) => MappingRecord(
  batchId: 'b1',
  alarmId: 'a1',
  tag: tag,
  at: DateTime.parse(at),
  title: title,
  registeredAt: DateTime.parse('2026-11-22T09:00:00'),
);

/// Old record (OLD) that is current before the replace.
MappingRecord _oldRecord() =>
    _record(_oldTag, '2026-11-22T12:00:00+09:00', '旧');

/// New record (PND) that replaces [_oldRecord].
MappingRecord _newRecord() =>
    _record(_newTag, '2026-11-22T13:00:00+09:00', '新');

/// Tag of the second new (pending) row, replacing PND.
const String _newTag2 = '20261122100000-a1b2c3d4-0123456789abcdef';

/// Second new record (PN2) that replaces [_newRecord] while it is still pending.
MappingRecord _newRecord2() =>
    _record(_newTag2, '2026-11-22T14:00:00+09:00', '新2');

/// Tag of the old row of the key (b2, a2).
const String _oldTagB2 = '20261122091000-a1b2c3d4-0123456789abcdef';

/// Tag of the new (pending) row of the key (b2, a2).
const String _newTagB2 = '20261122103000-a1b2c3d4-0123456789abcdef';

/// Record of the key (b2, a2) with [tag] and [at].
MappingRecord _recordB2(String tag, String at) => MappingRecord(
  batchId: 'b2',
  alarmId: 'a2',
  tag: tag,
  at: DateTime.parse(at),
  title: 'b2',
  registeredAt: DateTime.parse('2026-11-22T09:00:00'),
);

/// Record of the key (b9, a9) that already holds [_newTag] (PND).
MappingRecord _recordB9WithNewTag() => MappingRecord(
  batchId: 'b9',
  alarmId: 'a9',
  tag: _newTag,
  at: DateTime.parse('2026-11-22T15:00:00+09:00'),
  title: 'b9',
  registeredAt: DateTime.parse('2026-11-22T09:00:00'),
);

/// New record of the key (b2, a2) that replaces its old row (same values in every use).
MappingRecord _newRecordB2() =>
    _recordB2(_newTagB2, '2026-11-22T13:30:00+09:00');

/// Creates a fresh temp directory, runs [body] with a DB path in it, then deletes it.
Future<void> _withDbPath(Future<void> Function(String path) body) async {
  final Directory dir = Directory.systemTemp.createTempSync('kallr_rpq_');
  try {
    await body('${dir.path}${Platform.pathSeparator}mappings.sqlite3');
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// Opens a store on [path], runs [body] with it, and always closes the store
/// (an open store keeps the file locked on Windows).
Future<T> _withStore<T>(
  String path,
  FutureOr<T> Function(SqliteStore store) body,
) async {
  final SqliteStore store = SqliteStore.open(path);
  try {
    return await body(store);
  } finally {
    store.close();
  }
}

/// Puts [_oldRecord] and replaces it with [_newRecord] on a store at [path].
///
/// Returns the value of `replace`. Read the tables back AFTER this returns.
Future<int> _putOldThenReplace(String path) =>
    _withStore(path, (SqliteStore store) {
      store.put(_oldRecord());
      return store.replace(_newRecord());
    });

/// Puts [_oldRecord], replaces it with [_newRecord], then replaces again with
/// [_newRecord2] while PND is still pending.
///
/// Returns the values of the first and the second `replace`.
Future<(int, int)> _replaceTwice(String path) =>
    _withStore(path, (SqliteStore store) {
      store.put(_oldRecord());
      final int first = store.replace(_newRecord());
      return (first, store.replace(_newRecord2()));
    });

/// Puts [_oldRecord], replaces it with [_newRecord], then runs [read] on the
/// same store, so the lookups see the state right after `replace`.
///
/// Returns the value of [read].
Future<T> _readAfterReplace<T>(
  String path,
  FutureOr<T> Function(SqliteStore store) read,
) => _withStore(path, (SqliteStore store) {
  store.put(_oldRecord());
  store.replace(_newRecord());
  return read(store);
});

/// Puts [_oldRecord], replaces it with [_newRecord], completes the removal of
/// the queued old row, then runs [read] on the same store.
///
/// Returns the value of [read].
Future<T> _readAfterCompleteRemoval<T>(
  String path,
  FutureOr<T> Function(SqliteStore store) read,
) => _withStore(path, (SqliteStore store) {
  _putReplaceComplete(store);
  return read(store);
});

/// Puts [_oldRecord], replaces it with [_newRecord], aborts the queued
/// replacement, then runs [read] on the same store.
///
/// Returns the value of [read].
Future<T> _readAfterAbortReplacement<T>(
  String path,
  FutureOr<T> Function(SqliteStore store) read,
) => _withStore(path, (SqliteStore store) {
  store.put(_oldRecord());
  store.abortReplacement(store.replace(_newRecord()));
  return read(store);
});

/// Puts [_oldRecord], replaces it with [_newRecord], completes the removal, then
/// aborts the same (already completed) queue row again, and runs [read] on the same store.
///
/// Returns the value of [read].
Future<T> _readAfterStaleAbort<T>(
  String path,
  FutureOr<T> Function(SqliteStore store) read,
) => _withStore(path, (SqliteStore store) {
  store.abortReplacement(_putReplaceComplete(store));
  return read(store);
});

/// On [store]: puts [_oldRecord], replaces it with [_newRecord], then puts the old
/// row of (b2, a2) and replaces it with [_newRecordB2]. Both removals stay pending.
///
/// Returns the queueId of the first (b1, a1) replace.
int _putAndReplaceB1ThenB2(SqliteStore store) {
  store.put(_oldRecord());
  final int queueId1 = store.replace(_newRecord());
  store.put(_recordB2(_oldTagB2, '2026-11-22T12:30:00+09:00'));
  store.replace(_newRecordB2());
  return queueId1;
}

/// On [store]: puts [_oldRecord], replaces it with [_newRecord] and completes
/// the removal of the queued old row.
///
/// Returns the queueId of that (now completed) queue row.
int _putReplaceComplete(SqliteStore store) {
  store.put(_oldRecord());
  final int queueId = store.replace(_newRecord());
  store.completeRemoval(queueId);
  return queueId;
}

/// Expects [pending] to hold exactly one removal, with [oldTag] and [record].
void _expectSinglePending(
  List<PendingRemoval> pending,
  String oldTag,
  MappingRecord record,
) {
  expect(pending, hasLength(1));
  expect(pending.single.oldTag, oldTag);
  expect(pending.single.record, record);
}

/// Puts (b9, a9) with PND and [_oldRecord], then replaces (b1, a1) with [_newRecord],
/// whose Tag (PND) collides with the one of (b9, a9). The returned future fails.
Future<int> _putCollidingThenReplace(String path) =>
    _withStore(path, (SqliteStore store) {
      store.put(_recordB9WithNewTag());
      store.put(_oldRecord());
      return store.replace(_newRecord());
    });

/// Runs [_putCollidingThenReplace] and swallows its [StorageException], so the
/// caller can read the tables back (the store is closed by then).
Future<void> _putCollidingThenReplaceIgnoringFailure(String path) async {
  try {
    await _putCollidingThenReplace(path);
  } on StorageException {
    // expected: the tables are checked by the caller
  }
}

/// Puts [_oldRecord], then replaces (b1, a1) with a record whose Tag is the same
/// as the old row (OLD). The returned future fails.
Future<int> _putOldThenReplaceSameTag(String path) =>
    _withStore(path, (SqliteStore store) {
      store.put(_oldRecord());
      return store.replace(_record(_oldTag, '2026-11-22T13:00:00+09:00', '新'));
    });

/// Runs [_putOldThenReplaceSameTag] and swallows its [StorageException], so the
/// caller can read the tables back (the store is closed by then).
Future<void> _putOldThenReplaceSameTagIgnoringFailure(String path) async {
  try {
    await _putOldThenReplaceSameTag(path);
  } on StorageException {
    // expected: the tables are checked by the caller
  }
}

/// Reads `notify_status` of the `notifications` row whose tag is [tag].
int _readStatus(String path, String tag) {
  final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return db.select('SELECT notify_status FROM notifications WHERE tag = ?', [
          tag,
        ]).single['notify_status']
        as int;
  } finally {
    db.close();
  }
}

/// Reads the physical id of the `notifications` row whose tag is [tag].
int _readId(String path, String tag) {
  final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return db.select('SELECT id FROM notifications WHERE tag = ?', [
          tag,
        ]).single['id']
        as int;
  } finally {
    db.close();
  }
}

/// Reads every `replacement_queue` row as (id, new_id, old_id) triples.
List<(int, int, int?)> _readQueue(String path) {
  final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return db
        .select('SELECT id, new_id, old_id FROM replacement_queue ORDER BY id')
        .map(
          (Row r) => (r['id'] as int, r['new_id'] as int, r['old_id'] as int?),
        )
        .toList();
  } finally {
    db.close();
  }
}

/// Counts the rows of [table] ([table] is a fixed table name, never user input).
int _countRows(String path, String table) {
  final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return db.select('SELECT COUNT(*) AS n FROM $table').single['n'] as int;
  } finally {
    db.close();
  }
}

/// Counts the `notifications` rows that are pending (`notify_status` 2).
int _countPendingRows(String path) {
  final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return db
            .select(
              'SELECT COUNT(*) AS n FROM notifications WHERE notify_status = 2',
            )
            .single['n']
        as int;
  } finally {
    db.close();
  }
}

void main() {
  // SqliteStore.replace: supersedes the current row and queues the removal of its OS notification.
  group('T-WDV-RPQ: replace', () {
    group(
      'Given: 旧行 (OLD) が current で replace した直後 (SCH-R-009 段階 1, SCH-DD-01)',
      () {
        group('When: 正常系 (replace(PND) を呼ぶ)', () {
          test(
            '[Normal] T-WDV-RPQ-01: 新行 (PND) は pending (2) で追加される',
            () async {
              await _withDbPath((String path) async {
                await _putOldThenReplace(path);

                expect(_readStatus(path, _newTag), 2);
              });
            },
          );

          test(
            '[Normal] T-WDV-RPQ-02: 旧行 (OLD) は superseded (0) になる',
            () async {
              await _withDbPath((String path) async {
                await _putOldThenReplace(path);

                expect(_readStatus(path, _oldTag), 0);
              });
            },
          );

          test(
            '[Normal] T-WDV-RPQ-03: キューに (新行の id, 旧行の id) の 1 行だけが入る',
            () async {
              await _withDbPath((String path) async {
                await _putOldThenReplace(path);

                expect(_readQueue(path).map((r) => (r.$2, r.$3)).toList(), [
                  (_readId(path, _newTag), _readId(path, _oldTag)),
                ]);
              });
            },
          );

          test('[Normal] T-WDV-RPQ-04: 戻り値はキューの行の id である', () async {
            await _withDbPath((String path) async {
              final int queueId = await _putOldThenReplace(path);

              expect(_readQueue(path).map((r) => r.$1).toList(), [queueId]);
            });
          });
        });
      },
    );

    group('Given: 置換する旧行 (b1/a1) が無い (T-06-13)', () {
      group('When: 異常系 (replace(PND) を呼ぶ)', () {
        // T-06-13-01
        test('[Error] T-WDV-RPQ-05: StorageException を投げる', () async {
          await _withDbPath((String path) async {
            await _withStore(path, (SqliteStore store) {
              expect(
                () => store.replace(_newRecord()),
                throwsA(isA<StorageException>()),
              );
            });
          });
        });

        // T-06-13-02
        test('[Error] T-WDV-RPQ-06: 失敗後、notifications と replacement_queue は 0 件のままである', () async {
          await _withDbPath((String path) async {
            await _withStore(path, (SqliteStore store) {
              try {
                store.replace(_newRecord());
              } on StorageException {
                // expected: the rows are checked below
              }
            });

            expect(_countRows(path, 'notifications'), 0);
            expect(_countRows(path, 'replacement_queue'), 0);
          });
        });
      });
    });

    group('Given: 前の置換 (PND) が未完了 (pending) の状態 (T-06-14)', () {
      group('When: エッジケース (replace(PN2) をもう一度呼ぶ)', () {
        // T-06-14-01
        test('[Edge] T-WDV-RPQ-07: 前の置換後の行 (PND) は削除される', () async {
          await _withDbPath((String path) async {
            await _replaceTwice(path);

            expect(_countRows(path, "notifications WHERE tag = '$_newTag'"), 0);
          });
        });

        // T-06-14-02
        test(
          '[Edge] T-WDV-RPQ-08: キューは (PN2 の id, OLD の id) の 1 行だけになる',
          () async {
            await _withDbPath((String path) async {
              await _replaceTwice(path);

              expect(_readQueue(path).map((r) => (r.$2, r.$3)).toList(), [
                (_readId(path, _newTag2), _readId(path, _oldTag)),
              ]);
            });
          },
        );

        // T-06-14-03
        test('[Edge] T-WDV-RPQ-09: OLD は superseded (0) のまま、PN2 は pending (2) で追加される', () async {
          await _withDbPath((String path) async {
            await _replaceTwice(path);

            expect(
              (_readStatus(path, _oldTag), _readStatus(path, _newTag2)),
              (0, 2),
            );
          });
        });

        // T-06-14-04
        test('[Edge] T-WDV-RPQ-10: 戻り値は新しいキューの行の id で、前回の戻り値と異なる', () async {
          await _withDbPath((String path) async {
            final (int first, int second) = await _replaceTwice(path);

            expect(_readQueue(path).map((r) => r.$1).toList(), [second]);
            expect(second, isNot(first));
          });
        });
      });
    });

    group('Given: 旧行 (OLD) が current で replace した直後 (T-06-02)', () {
      group('When: 正常系 (get / all / tags を呼ぶ)', () {
        // T-06-02-01
        test('[Normal] T-WDV-RPQ-11: get(b1, a1) は新行 (PND) を返す', () async {
          await _withDbPath((String path) async {
            final MappingRecord? got = await _readAfterReplace(
              path,
              (SqliteStore store) => store.get('b1', 'a1'),
            );

            expect(got, _newRecord());
          });
        });

        // T-06-02-02
        test(
          '[Normal] T-WDV-RPQ-12: all() は新行 (PND) だけを返し、旧行 (OLD) を含まない',
          () async {
            await _withDbPath((String path) async {
              final List<MappingRecord> got = await _readAfterReplace(
                path,
                (SqliteStore store) => store.all(),
              );

              expect(got, [_newRecord()]);
            });
          },
        );

        // T-06-02-03
        test('[Normal] T-WDV-RPQ-13: tags() は OLD と PND の両方を含む', () async {
          await _withDbPath((String path) async {
            final Set<String> got = await _readAfterReplace(
              path,
              (SqliteStore store) => store.tags(),
            );

            expect(got, {_oldTag, _newTag});
          });
        });
      });
    });

    group('Given: 保留が 1 件ある (T-06-03)', () {
      group('When: 正常系 (pendingRemovals を呼ぶ)', () {
        // T-06-03-01
        test(
          '[Normal] T-WDV-RPQ-14: 1 件を返し、queueId・旧行の Tag・Group・置換後の値を持つ',
          () async {
            await _withDbPath((String path) async {
              final (int queueId, List<PendingRemoval> got) = await _withStore(
                path,
                (SqliteStore store) {
                  store.put(_oldRecord());
                  final int id = store.replace(_newRecord());
                  return (id, store.pendingRemovals());
                },
              );

              expect(got, [
                PendingRemoval(
                  queueId: queueId,
                  oldTag: _oldTag,
                  group: kGroup,
                  record: _newRecord(),
                ),
              ]);
            });
          },
        );
      });
    });

    group('Given: 保留が 2 件ある (T-06-04)', () {
      group('When: 正常系 (pendingRemovals を呼ぶ)', () {
        // T-06-04-01
        test(
          '[Normal] T-WDV-RPQ-15: b1/a1、b2/a2 の順 (queueId 昇順) で 2 件を返す',
          () async {
            await _withDbPath((String path) async {
              final MappingRecord newB2 = _recordB2(
                _newTagB2,
                '2026-11-22T14:00:00+09:00',
              );
              final List<PendingRemoval> got = await _withStore(path, (
                SqliteStore store,
              ) {
                store.put(_oldRecord());
                store.put(_recordB2(_oldTagB2, '2026-11-22T12:30:00+09:00'));
                store.replace(_newRecord());
                store.replace(newB2);
                return store.pendingRemovals();
              });

              expect(
                got.map((PendingRemoval p) => (p.oldTag, p.record)).toList(),
                [(_oldTag, _newRecord()), (_oldTagB2, newB2)],
              );
              expect(got[0].queueId, lessThan(got[1].queueId));
            });
          },
        );
      });
    });

    group('Given: 保留を completeRemoval した後 (T-06-05, SCH-R-009 段階 4)', () {
      group('When: 状態遷移 (completeRemoval(queueId) を呼ぶ)', () {
        // T-06-05-01
        test('[Normal] T-WDV-RPQ-16: 旧行 (OLD) は notifications から消える', () async {
          await _withDbPath((String path) async {
            await _readAfterCompleteRemoval(path, (SqliteStore store) {});

            final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
            try {
              expect(
                db.select('SELECT id FROM notifications WHERE tag = ?', [
                  _oldTag,
                ]),
                isEmpty,
              );
            } finally {
              db.close();
            }
          });
        });

        // T-06-05-02
        test('[Normal] T-WDV-RPQ-17: 新行 (PND) は current (1) になる', () async {
          await _withDbPath((String path) async {
            await _readAfterCompleteRemoval(path, (SqliteStore store) {});

            expect(_readStatus(path, _newTag), 1);
          });
        });

        // T-06-05-03
        test('[Normal] T-WDV-RPQ-18: replacement_queue の行は 1 件残り、old_id は NULL になる', () async {
          await _withDbPath((String path) async {
            await _readAfterCompleteRemoval(path, (SqliteStore store) {});

            final List<(int, int, int?)> queue = _readQueue(path);
            expect(queue, hasLength(1));
            expect(queue.single.$2, _readId(path, _newTag));
            expect(queue.single.$3, isNull);
          });
        });

        // T-06-05-04
        test('[Normal] T-WDV-RPQ-19: pendingRemovals() は空のリストを返す', () async {
          await _withDbPath((String path) async {
            final List<PendingRemoval> got = await _readAfterCompleteRemoval(
              path,
              (SqliteStore store) => store.pendingRemovals(),
            );

            expect(got, isEmpty);
          });
        });

        // T-06-05-05
        test('[Normal] T-WDV-RPQ-20: tags() は PND を含み OLD を含まない', () async {
          await _withDbPath((String path) async {
            final Set<String> got = await _readAfterCompleteRemoval(
              path,
              (SqliteStore store) => store.tags(),
            );

            expect(got, {_newTag});
          });
        });
      });
    });

    group('Given: 保留を abortReplacement した後 (T-06-06, SCH-R-010)', () {
      group('When: 状態遷移 (abortReplacement(queueId) を呼ぶ)', () {
        // T-06-06-01
        test('[Normal] T-WDV-RPQ-21: 新行 (PND) は notifications から消える', () async {
          await _withDbPath((String path) async {
            await _readAfterAbortReplacement(path, (SqliteStore store) {});

            final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
            try {
              expect(
                db.select('SELECT id FROM notifications WHERE tag = ?', [
                  _newTag,
                ]),
                isEmpty,
              );
            } finally {
              db.close();
            }
          });
        });

        // T-06-06-02
        test('[Normal] T-WDV-RPQ-22: replacement_queue の行は残らない', () async {
          await _withDbPath((String path) async {
            await _readAfterAbortReplacement(path, (SqliteStore store) {});

            expect(_readQueue(path), isEmpty);
          });
        });

        // T-06-06-03
        test('[Normal] T-WDV-RPQ-23: 旧行 (OLD) は current (1) に戻る', () async {
          await _withDbPath((String path) async {
            await _readAfterAbortReplacement(path, (SqliteStore store) {});

            expect(_readStatus(path, _oldTag), 1);
          });
        });

        // T-06-06-04
        test('[Normal] T-WDV-RPQ-24: get は旧行 (OLD) の値を返す', () async {
          await _withDbPath((String path) async {
            final MappingRecord? got = await _readAfterAbortReplacement(
              path,
              (SqliteStore store) => store.get('b1', 'a1'),
            );

            expect(got, _oldRecord());
          });
        });

        // T-06-06-05
        test('[Normal] T-WDV-RPQ-25: pendingRemovals() は空のリストを返す', () async {
          await _withDbPath((String path) async {
            final List<PendingRemoval> got = await _readAfterAbortReplacement(
              path,
              (SqliteStore store) => store.pendingRemovals(),
            );

            expect(got, isEmpty);
          });
        });
      });
    });

    // fix: abort guard
    group('Given: abortReplacement を呼べない状態 (完了済み / 未知の queueId)', () {
      group('When: 完了済みの queueId で abortReplacement を呼ぶ', () {
        // fix: abort guard
        test(
          '[Edge] T-WDV-RPQ-26: PND は current (1) のまま残り、get は PND を返す',
          () async {
            await _withDbPath((String path) async {
              final MappingRecord? got = await _readAfterStaleAbort(
                path,
                (SqliteStore store) => store.get('b1', 'a1'),
              );

              expect(_readStatus(path, _newTag), 1);
              expect(got, _newRecord());
            });
          },
        );

        // fix: abort guard
        test('[Edge] T-WDV-RPQ-27: 完了済みの queue 行 (old_id NULL) は残り、notifications は 1 行', () async {
          await _withDbPath((String path) async {
            await _readAfterStaleAbort(path, (SqliteStore store) {});

            final List<(int, int, int?)> queue = _readQueue(path);
            expect(queue, hasLength(1));
            expect(queue.single.$3, isNull);
            expect(_countRows(path, 'notifications'), 1);
          });
        });
      });

      group('When: 未知の queueId で abortReplacement を呼ぶ', () {
        // fix: abort guard
        test('[Edge] T-WDV-RPQ-28: 何も変わらず例外も出ない', () async {
          await _withDbPath((String path) async {
            await _putOldThenReplace(path);
            final List<(int, int, int?)> queueBefore = _readQueue(path);

            await _withStore(
              path,
              (SqliteStore store) => store.abortReplacement(9999),
            );

            expect(_readQueue(path), queueBefore);
            expect(_countRows(path, 'notifications'), 2);
            expect(_readStatus(path, _oldTag), 0);
            expect(_readStatus(path, _newTag), 2);
          });
        });
      });
    });

    group('Given: 完了済みのキュー行がある (purgeCompletedQueue)', () {
      group('When: 状態遷移 (purgeCompletedQueue を呼ぶ)', () {
        // purge
        test('[Normal] T-WDV-RPQ-29: 完了済みの行だけを消して 1 を返し、notifications は PND の 1 行が残る', () async {
          await _withDbPath((String path) async {
            final int purged = await _readAfterCompleteRemoval(
              path,
              (SqliteStore store) => store.purgeCompletedQueue(),
            );

            expect(purged, 1);
            expect(_readQueue(path), isEmpty);
            expect(_countRows(path, 'notifications'), 1);
            expect(_readStatus(path, _newTag), 1);
          });
        });
      });

      group('When: エッジケース (未完了の置換だけがある)', () {
        // purge
        test(
          '[Edge] T-WDV-RPQ-30: 0 を返し、キューの行は変わらず pendingRemovals() は 1 件を返す',
          () async {
            await _withDbPath((String path) async {
              await _putOldThenReplace(path);
              final List<(int, int, int?)> queueBefore = _readQueue(path);

              final (
                int purged,
                List<PendingRemoval> pending,
              ) = await _withStore(
                path,
                (SqliteStore store) =>
                    (store.purgeCompletedQueue(), store.pendingRemovals()),
              );

              expect(purged, 0);
              expect(_readQueue(path), queueBefore);
              expect(pending, hasLength(1));
            });
          },
        );
      });

      group('When: エッジケース (完了済みと未完了が混在する)', () {
        // purge
        test(
          '[Edge] T-WDV-RPQ-31: 完了済みの 1 件だけを消して 1 を返し、未完了 (b2) は残る',
          () async {
            await _withDbPath((String path) async {
              final (
                int purged,
                List<PendingRemoval> pending,
              ) = await _withStore(path, (SqliteStore store) {
                _putReplaceComplete(store);
                store.put(_recordB2(_oldTagB2, '2026-11-22T12:30:00+09:00'));
                store.replace(_newRecordB2());
                return (store.purgeCompletedQueue(), store.pendingRemovals());
              });

              expect(purged, 1);
              final List<(int, int, int?)> queue = _readQueue(path);
              expect(queue, hasLength(1));
              expect(queue.single.$2, _readId(path, _newTagB2));
              expect(queue.single.$3, _readId(path, _oldTagB2));
              _expectSinglePending(pending, _oldTagB2, _newRecordB2());
            });
          },
        );
      });

      group('When: エッジケース (キューが空)', () {
        // purge
        test('[Edge] T-WDV-RPQ-32: 0 を返し、例外も出ない', () async {
          await _withDbPath((String path) async {
            final int purged = await _withStore(
              path,
              (SqliteStore store) => store.purgeCompletedQueue(),
            );

            expect(purged, 0);
          });
        });
      });
    });

    group('Given: 置換後の Tag が別のキーの Tag と衝突する replace (T-06-07, SCH-R-026)', () {
      group('When: 異常系 (b9/a9 が PND を持つとき replace(b1/a1, PND) を呼ぶ)', () {
        // T-06-07-01
        test('[Error] T-WDV-RPQ-33: StorageException を投げる', () async {
          await _withDbPath((String path) async {
            await expectLater(
              _putCollidingThenReplace(path),
              throwsA(isA<StorageException>()),
            );
          });
        });

        // T-06-07-02
        test(
          '[Error] T-WDV-RPQ-34: 失敗後、旧行 (OLD) は current (1) のまま変わらない',
          () async {
            await _withDbPath((String path) async {
              await _putCollidingThenReplaceIgnoringFailure(path);

              expect(_readStatus(path, _oldTag), 1);
            });
          },
        );

        // T-06-07-03
        test('[Error] T-WDV-RPQ-35: 失敗後、replacement_queue は 0 件で notifications に pending (2) の行が無い', () async {
          await _withDbPath((String path) async {
            await _putCollidingThenReplaceIgnoringFailure(path);

            expect(_countRows(path, 'replacement_queue'), 0);
            expect(_countPendingRows(path), 0);
          });
        });
      });
    });

    group('Given: 置換後の Tag が旧行の Tag と同じ replace (T-06-08, SCH-R-026)', () {
      group('When: 異常系 (旧行が OLD を持つとき replace(b1/a1, OLD) を呼ぶ)', () {
        // T-06-08-01
        test('[Error] T-WDV-RPQ-36: StorageException を投げる', () async {
          await _withDbPath((String path) async {
            await expectLater(
              _putOldThenReplaceSameTag(path),
              throwsA(isA<StorageException>()),
            );
          });
        });

        // T-06-08-02
        test(
          '[Error] T-WDV-RPQ-37: 失敗後、旧行 (OLD) は current (1) のまま変わらない',
          () async {
            await _withDbPath((String path) async {
              await _putOldThenReplaceSameTagIgnoringFailure(path);

              expect(_readStatus(path, _oldTag), 1);
            });
          },
        );
      });
    });

    group('Given: 2 件の保留のうち 1 件を complete する (T-06-09)', () {
      group('When: 状態遷移 (b1/a1 の queueId で completeRemoval を呼ぶ)', () {
        // T-06-09-01
        test(
          '[Normal] T-WDV-RPQ-38: pendingRemovals() は b2/a2 の 1 件だけを返す',
          () async {
            await _withDbPath((String path) async {
              final List<PendingRemoval> pending = await _withStore(path, (
                SqliteStore store,
              ) {
                store.completeRemoval(_putAndReplaceB1ThenB2(store));
                return store.pendingRemovals();
              });

              _expectSinglePending(pending, _oldTagB2, _newRecordB2());
            });
          },
        );
      });
    });

    group('Given: 2 件の保留のうち 1 件を abort する (T-06-10)', () {
      group('When: 状態遷移 (b1/a1 の queueId で abortReplacement を呼ぶ)', () {
        // T-06-10-01
        test(
          '[Normal] T-WDV-RPQ-39: b2/a2 の新行は notify_status = 2 のまま',
          () async {
            await _withDbPath((String path) async {
              await _withStore(path, (SqliteStore store) {
                store.abortReplacement(_putAndReplaceB1ThenB2(store));
              });

              expect(_readStatus(path, _newTagB2), 2);
            });
          },
        );
      });
    });

    group('Given: 完了後にもう一度 replace する (T-06-11, AUTOINCREMENT)', () {
      group('When: 状態遷移 (同じキーを別の Tag で再度 replace する)', () {
        // T-06-11-01
        test('[Normal] T-WDV-RPQ-40: 2 回目の戻り値は 1 回目の queueId より大きい', () async {
          await _withDbPath((String path) async {
            final (int queueId1, int queueId2) = await _withStore(path, (
              SqliteStore store,
            ) {
              final int first = _putReplaceComplete(store);
              return (first, store.replace(_newRecord2()));
            });

            expect(queueId2, greaterThan(queueId1));
          });
        });
      });
    });

    group('Given: 完了済みのキュー行が残っている状態で、同じキーをもう一度 replace する (T-06-12)', () {
      group('When: pendingRemovals() を呼ぶ', () {
        // T-06-12-01
        test('[Normal] T-WDV-RPQ-41: 完了済みの行は含まれず、2 回目の待機中の 1 件だけを返す', () async {
          await _withDbPath((String path) async {
            final List<PendingRemoval> pending = await _withStore(path, (
              SqliteStore store,
            ) {
              _putReplaceComplete(store);
              store.replace(_newRecord2());
              return store.pendingRemovals();
            });

            _expectSinglePending(pending, _newTag, _newRecord2());
          });
        });
      });
    });
  });
}
