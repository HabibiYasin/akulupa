/// Extension point for a consistent DB snapshot and referenced photos.
/// A future implementation must export via SQLite backup/VACUUM INTO, not copy
/// a live database file while WAL writes are in progress.
abstract interface class BackupService {
  Future<BackupResult> export();
}

class BackupResult {
  const BackupResult({
    required this.available,
    required this.message,
    this.path,
  });
  final bool available;
  final String message;
  final String? path;
}

class LocalBackupService implements BackupService {
  @override
  Future<BackupResult> export() async => const BackupResult(
    available: false,
    message: 'Ekspor cadangan belum tersedia pada MVP.',
  );
}
