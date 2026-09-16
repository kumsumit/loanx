import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/service/auth_client.dart';
import 'package:loanx/service/database_helper.dart';

void main() {
  test(
    'links remote identity without replacing local owner and party IDs',
    () async {
      final db = await DatabaseHelper.instance.openMemory(
        name: 'account-link-${DateTime.now().microsecondsSinceEpoch}',
      );
      final now = DateTime.utc(2026, 9, 16).toIso8601String();
      await db.insert('localOwners', {
        'id': 'local-owner',
        'selfPartyId': 'local-party',
        'createdAt': now,
      });
      await db.insert('parties', {
        'id': 'local-party',
        'ownerId': 'local-owner',
        'displayName': 'Owner',
        'status': 'ACTIVE',
        'createdAt': now,
        'updatedAt': now,
      });
      const identity = CloudIdentity(
        userId: 'remote-user',
        workspaceId: 'remote-workspace',
        selfPartyId: 'remote-party',
        phoneE164: '+919999999999',
      );

      await AuthClient().linkLocalOwner(identity, database: db);

      final owner = (await db.query('localOwners')).single;
      final party = (await db.query('parties')).single;
      expect(owner['id'], 'local-owner');
      expect(owner['selfPartyId'], 'local-party');
      expect(owner['remoteUserId'], 'remote-user');
      expect(owner['remoteWorkspaceId'], 'remote-workspace');
      expect(owner['remotePartyId'], 'remote-party');
      expect(party['userId'], 'remote-user');

      await AuthClient().linkLocalOwner(
        const CloudIdentity(
          userId: 'another-user',
          workspaceId: 'another-workspace',
          selfPartyId: 'another-party',
          phoneE164: '+918888888888',
        ),
        database: db,
      );
      final unchangedOwner = (await db.query('localOwners')).single;
      final unchangedParty = (await db.query('parties')).single;
      expect(unchangedOwner['remoteUserId'], 'remote-user');
      expect(unchangedParty['userId'], 'remote-user');
      await db.close();
    },
  );
}
