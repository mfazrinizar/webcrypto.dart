// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

part of 'impl_jni.dart';

final class _HashImpl implements HashImpl {
  const _HashImpl(this._jcaName);

  final String _jcaName;

  @override
  Future<Uint8List> digestBytes(List<int> data) async {
    return jni.using((arena) {
      final algorithm = jni.JString.fromString(_jcaName)..releasedBy(arena);
      final digest = MessageDigest.getInstance(algorithm);
      if (digest == null) {
        throw operationError('JCA MessageDigest($_jcaName) is unavailable');
      }
      digest.releasedBy(arena);

      final input = jni.JByteArray.from(data)..releasedBy(arena);
      final result = digest.digest$1(input);
      if (result == null) {
        throw operationError('JCA MessageDigest($_jcaName) returned null');
      }
      result.releasedBy(arena);

      return _copyJByteArray(result);
    });
  }

  @override
  Future<Uint8List> digestStream(Stream<List<int>> data) async {
    final algorithm = jni.JString.fromString(_jcaName);
    final digest = MessageDigest.getInstance(algorithm);
    algorithm.release();

    if (digest == null) {
      throw operationError('JCA MessageDigest($_jcaName) is unavailable');
    }

    try {
      await for (final chunk in data) {
        jni.using((arena) {
          final input = jni.JByteArray.from(chunk)..releasedBy(arena);
          digest.update$1(input);
        });
      }

      final result = digest.digest();
      if (result == null) {
        throw operationError('JCA MessageDigest($_jcaName) returned null');
      }
      try {
        return _copyJByteArray(result);
      } finally {
        result.release();
      }
    } finally {
      digest.release();
    }
  }
}

/// Copies a JVM byte array into Dart-owned memory.
///
/// `JByteArray.getRange` returns a typed list backed by a native buffer whose
/// lifetime is finalizer-driven. Copy once more before releasing the Java array
/// so webcrypto callers receive a normal Dart-managed [Uint8List].
Uint8List _copyJByteArray(jni.JByteArray array) {
  final bytes = array.getRange(0, array.length);
  final view = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.length);
  return Uint8List.fromList(view);
}
