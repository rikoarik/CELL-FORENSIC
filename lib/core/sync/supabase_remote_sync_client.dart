import 'package:cell_forensic/core/supabase/supabase_config.dart';
import 'package:cell_forensic/core/sync/student_answer_payload.dart';
import 'package:cell_forensic/core/sync/sync_operation.dart';
import 'package:cell_forensic/core/sync/sync_queue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pushes [SyncOperation] payloads to Supabase tables (E1-05).
///
/// Maps [SyncOperation.entityType] → table name. Uses idempotency via upsert on
/// `id` when the payload contains one. Throws [RemoteFailure] so the queue can
/// apply backoff.
///
/// `answers` uses E10 column-safe insert/update (never teacher score columns;
/// DELETE privilege is revoked for anon — delete ops fail with RemoteFailure).
class SupabaseRemoteSyncClient implements RemoteSyncClient {
  const SupabaseRemoteSyncClient();

  @override
  Future<void> push(SyncOperation operation) async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) {
      throw const RemoteFailure(
        'Supabase belum dikonfigurasi',
        retryable: false,
      );
    }

    final table = operation.entityType;
    try {
      switch (operation.opType) {
        case SyncOpType.create:
        case SyncOpType.update:
          if (table == 'answers') {
            await _pushAnswer(client, operation);
          } else {
            await client.from(table).upsert(operation.payload);
          }
        case SyncOpType.delete:
          final id = operation.entityId;
          await client.from(table).delete().eq('id', id);
      }
    } on PostgrestException catch (error) {
      final code = error.code ?? '';
      final retryable = code.startsWith('5') || code == '408' || code == '429';
      throw RemoteFailure(error.message, retryable: retryable);
    } catch (error) {
      throw RemoteFailure('$error', retryable: true);
    }
  }

  /// Student path: INSERT allowed columns, then UPDATE only E10-safe columns.
  Future<void> _pushAnswer(
    SupabaseClient client,
    SyncOperation operation,
  ) async {
    final id = operation.payload['id'] as String? ?? operation.entityId;
    final updatePayload = StudentAnswerPayload.forUpdate(operation.payload);
    final insertPayload = StudentAnswerPayload.forInsert({
      ...operation.payload,
      'id': id,
    });

    if (operation.opType == SyncOpType.update) {
      final updated = await client
          .from('answers')
          .update(updatePayload)
          .eq('id', id)
          .select('id');
      if ((updated as List).isNotEmpty) return;
    }

    if (insertPayload['question_id'] == null) {
      throw const RemoteFailure(
        'answers insert membutuhkan question_id (E10)',
        retryable: false,
      );
    }
    await client.from('answers').upsert(insertPayload);
  }
}
