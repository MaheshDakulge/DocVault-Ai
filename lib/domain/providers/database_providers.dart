import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/database.dart';
import '../../data/local/daos/document_dao.dart';
import '../../data/local/daos/field_dao.dart';
import '../../data/local/daos/fts_dao.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final documentDaoProvider = Provider<DocumentDao>((ref) {
  return ref.watch(databaseProvider).documentDao;
});

final fieldDaoProvider = Provider<FieldDao>((ref) {
  return ref.watch(databaseProvider).fieldDao;
});

final ftsDaoProvider = Provider<FtsDao>((ref) {
  return ref.watch(databaseProvider).ftsDao;
});
