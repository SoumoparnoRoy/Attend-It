import 'package:flutter_test/flutter_test.dart';

import 'package:zeolite/data/settings/app_settings.dart';
import 'package:zeolite/services/backup_service.dart';

String _name(int day) => 'zeolite_backup_2026081${day}_0900.json';

void main() {
  group('choosing which backup files to prune', () {
    test('nothing goes while the folder is under the limit', () {
      expect(
        BackupService.namesToPrune(<String>[_name(1), _name(2)], 5),
        isEmpty,
      );
    });

    test('nothing goes when it sits exactly on the limit', () {
      expect(
        BackupService.namesToPrune(
          <String>[for (int i = 1; i <= 5; i++) _name(i)],
          5,
        ),
        isEmpty,
      );
    });

    test('the oldest go, by name, whatever order they arrive in', () {
      final List<String> pruned = BackupService.namesToPrune(
        <String>[_name(4), _name(1), _name(7), _name(2), _name(9), _name(3)],
        3,
      );

      expect(pruned, <String>[_name(1), _name(2), _name(3)]);
    });

    test('a keep of zero takes everything', () {
      expect(
        BackupService.namesToPrune(<String>[_name(1), _name(2)], 0),
        hasLength(2),
      );
    });
  });

  group('where an automatic backup goes', () {
    test('the app folder when none was ever chosen', () {
      expect(
        BackupService.destinationFor(folderUri: null, folderUsable: false),
        BackupDestination.appFolder,
      );
    });

    test('the chosen folder while the grant holds', () {
      expect(
        BackupService.destinationFor(
          folderUri: 'content://tree/primary%3ADocuments',
          folderUsable: true,
        ),
        BackupDestination.chosenFolder,
      );
    });

    test('back to the app once the grant is gone, rather than not at all', () {
      expect(
        BackupService.destinationFor(
          folderUri: 'content://tree/primary%3ADocuments',
          folderUsable: false,
        ),
        BackupDestination.appFolder,
      );
    });
  });

  group('the settings a backup folder is held in', () {
    test('no folder chosen is the default', () {
      expect(const AppSettings().hasBackupFolder, isFalse);
    });

    test('a chosen folder is remembered with its name', () {
      final AppSettings settings = const AppSettings().copyWith(
        backupFolderUri: 'content://tree/primary%3ADocuments',
        backupFolderName: 'Documents',
      );

      expect(settings.hasBackupFolder, isTrue);
      expect(settings.backupFolderName, 'Documents');
    });

    test('clearing it sets it back to null, which copyWith alone cannot', () {
      final AppSettings chosen = const AppSettings().copyWith(
        backupFolderUri: 'content://tree/primary%3ADocuments',
        backupFolderName: 'Documents',
      );

      final AppSettings cleared = chosen.copyWith(clearBackupFolder: true);

      expect(cleared.hasBackupFolder, isFalse);
      expect(cleared.backupFolderName, isNull);
    });

    test('the folder never travels in a backup', () {
      final AppSettings settings = const AppSettings().copyWith(
        backupFolderUri: 'content://tree/primary%3ADocuments',
        backupFolderName: 'Documents',
      );

      final Map<String, Object?> json = settings.toJson();

      expect(json.containsKey('backupFolderUri'), isFalse);
      expect(json.containsKey('backupFolderName'), isFalse);
    });

    test('and cannot be restored from one', () {
      final AppSettings restored = AppSettings.fromJson(<String, Object?>{
        'backupFolderUri': 'content://tree/someone%3Aelse',
        'backupFolderName': 'Their phone',
      });

      expect(restored.hasBackupFolder, isFalse);
    });

    test('restoring a backup keeps the folder this device already chose', () {
      const AppSettings onThisDevice = AppSettings(
        backupFolderUri: 'content://tree/primary%3Adocuments',
        backupFolderName: 'documents',
      );
      final AppSettings fromFile =
          AppSettings.fromJson(<String, Object?>{'targetPercent': 80});

      final AppSettings applied = fromFile.copyWith(
        backupFolderUri: onThisDevice.backupFolderUri,
        backupFolderName: onThisDevice.backupFolderName,
      );

      expect(applied.targetPercent, 80);
      expect(applied.backupFolderName, 'documents');
    });
  });
}
