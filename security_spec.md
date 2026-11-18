# Security Specification — AI Home Brain

## 1. Data Invariants
1. A `UserProfile` at `/users/{userId}` and `UserHouseholdLink` at `/users/{userId}/membership/current` can only be read (`get`) or written by the authenticated user whose `request.auth.uid == userId`. Listing `/users` is strictly denied to isolate PII (`email`).
2. Every write requires `request.auth.token.email_verified == true`.
3. `HomeState`, `ActivityEntry`, and `AutomationRoutine` under `/users/{userId}` require the parent `/users/{userId}` document to exist (`Master Gate`), and `ownerId` must equal `request.auth.uid`.
4. `Household` at `/homes/{homeId}` can only be read by its owner or active UIDs in `memberUids` (max 20). Listing `/homes` is denied.
5. `FamilyMember` at `/homes/{homeId}/members/{memberId}` requires active membership or ownership of `homeId`. Only household admins (`owner` or `canManageFamily == true`) can add, modify permissions for, or remove non-owner members. Non-owners cannot promote themselves or modify/remove the household owner.
6. `FamilyInvite` at `/homeInvites/{inviteCode}` can only be created/revoked by household admins, and can only be read or accepted by the verified user whose `request.auth.token.email` matches `invitedEmail`. Accepting an invite strictly enforces role and permission parity against the stored invite document.
7. `FamilyActivityEntry` at `/homes/{homeId}/activityLogs/{logId}` is append-only (`update` and `delete` denied), requires `actorUid == request.auth.uid`, and can only be listed by UIDs present in `viewerUids` without `get()`/`exists()` inside `allow list`.
8. Immutable fields (`uid`, `ownerId`, `homeId`, `homeOwnerId`, `createdAt`) cannot be modified on update; `createdAt` and `updatedAt` must equal `request.time`.
9. Document IDs are hardened via `isValidId(id)` (`^[a-zA-Z0-9_-]+$`, `<= 128` chars) and all strings/lists enforce explicit `.size()` upper bounds.

## 2. The "Dirty Dozen" Payloads (Expected: PERMISSION_DENIED)
1. **Unauthenticated read**: `get /users/user1` with `auth == null`.
2. **Cross-user PII read**: `get /users/user2` authenticated as `user1`.
3. **Blanket user list**: `list /users` authenticated as `user1`.
4. **Unverified email write**: `create /users/user1` with `email_verified: false`.
5. **Identity spoofing**: `create /users/user1` with `uid: "user2"`.
6. **Shadow field injection**: `create /users/user1` with extra `isAdmin: true`.
7. **Oversized displayName**: `create /users/user1` with `displayName` > 100 chars.
8. **Client-forged timestamp**: `create /users/user1` with `createdAt` != `request.time`.
9. **Orphaned HomeState**: `create /users/user1/homeState/default` when `/users/user1` does not exist.
10. **Invalid fanSpeed**: `update /users/user1/homeState/default` with `fanSpeed: 99`.
11. **Invalid selectedMode**: `update /users/user1/homeState/default` with `selectedMode: "AdminOverride"`.
12. **Immutable ownerId tampering**: `update /users/user1/homeState/default` changing `ownerId`.
13. **Cross-household member read**: `get /homes/home2/members/user2` authenticated as `user1` (not in `home2`).
14. **Privilege escalation on invite acceptance**: `create /homes/home1/members/user2` with `role: 'owner'` or `canManageFamily: true` when the invite at `/homeInvites/{inviteCode}` grants `role: 'guest'` and `canManageFamily: false`.
15. **Email spoofing on invite acceptance**: `update /homeInvites/INV12345` with `email_verified: false` even when email matches `invitedEmail`.
16. **Unauthorized member removal**: `delete /homes/home1/members/owner1` or `delete /homes/home1/members/user3` by a guest without `canManageFamily`.
17. **Activity log tampering**: `update` or `delete` on `/homes/home1/activityLogs/log1`, or `create` with `actorUid != request.auth.uid`.
