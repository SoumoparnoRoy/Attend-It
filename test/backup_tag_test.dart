import 'package:flutter_test/flutter_test.dart';
import 'package:zeolite/services/backup_service.dart';

void main() {
  group('backup tags', () {
    test('exports carry the current name', () {
      expect(BackupService.appTag, 'Zeolite');
    });

    test('a backup written before the rename still imports', () {
      expect(BackupService.isRecognisedTag('Attend It!'), isTrue);
      expect(BackupService.isRecognisedTag('Zeolite'), isTrue);
    });

    test('anything else is refused', () {
      expect(BackupService.isRecognisedTag('Some Other App'), isFalse);
      expect(BackupService.isRecognisedTag(null), isFalse);
      expect(BackupService.isRecognisedTag(42), isFalse);
    });
  });
}
