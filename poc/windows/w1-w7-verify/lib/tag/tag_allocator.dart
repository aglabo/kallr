// src: lib/tag/tag_allocator.dart
// @(#) : allocate a toast Tag from injected random and machine id providers
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import '../errors.dart';
import 'generate_tag.dart';
import 'providers.dart';

/// Maximum number of Tag generation attempts: the first one plus 3 regenerations.
const int kMaxTagAttempts = 4;

/// Allocates a Tag for [registeredAt] that is not in [existingTags].
///
/// The machine id is fetched once; only the random part is regenerated
/// while the built Tag is a duplicate. At most [kMaxTagAttempts] Tags are
/// built (the first attempt and 3 regenerations); no further random part is
/// fetched after that.
///
/// Throws [DuplicateTagException] with `attempts` set to [kMaxTagAttempts]
/// when every attempt is a duplicate.
String allocateTag({
  required RandomSourceProvider random,
  required MachineIdProvider machineId,
  required Set<String> existingTags,
  required DateTime registeredAt,
}) {
  final id = machineId.machineId();

  for (var attempt = 0; attempt < kMaxTagAttempts; attempt++) {
    final tag = generateTag(
      registeredAt: registeredAt,
      machineId: id,
      random: random.randomHex64(),
    );
    if (!existingTags.contains(tag)) {
      return tag;
    }
  }
  throw const DuplicateTagException(attempts: kMaxTagAttempts);
}
