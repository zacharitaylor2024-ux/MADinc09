# Mobile Application Development — In-Class Activity 09

## Local Storage, Part II: Card Catalogue

This Flutter app extends the Part I Fall Festival Roster with a SQLite-backed card catalogue. The original `my_table` guest roster remains available alongside the new `folders` and `cards` tables. Each card has a `folder_id` foreign key, and deleting a folder is intended to cascade to its cards.

### Project and setup

- Framework: Flutter / Dart
- Storage: `sqflite` SQLite database (with `path` and `path_provider`)
- Database filename: `MyDatabase.db`
- Database schema: version 2 (upgraded from version 1)
- Original table: `my_table` (`_id`, `name`, `age`)
- New tables: `folders`, `cards`
- Image choice: optional image URL stored as `image_ref`; a suit symbol is shown for null, malformed, or unavailable images
- Pathway: **Undergraduate**

From the project root:

```sh
flutter pub get
flutter analyze
flutter run
flutter build apk --release
```

**Migration safety:** Keep the original app installation and database contents; do not uninstall the existing app or clear app storage when testing the v1→v2 upgrade. Make a backup first. For testing the fresh-install path, use a separate emulator/profile or app ID.

### Architecture

- `lib/main.dart`: app launch, Part I roster, and navigation between roster and folders.
- `lib/database_helper.dart`: opens existing database, enables foreign keys, and handles versioned initialization.
- `lib/schema.dart`: schema creation / upgrade support.
- `lib/models.dart`: typed folder and card models.
- `lib/repository.dart`: database access and ID-based CRUD.
- `lib/screens.dart`: folder/card UI, forms, validation, image fallback, and delete confirmations.

### Test matrix — T1 through T6

Results below reflect **manual observations reported during testing**. Database IDs were not captured, and query-level checks are still pending; they are not fabricated here.

| Test | Expected | Observed | Status / remaining evidence |
|---|---|---|---|
| T1 — Upgrade preservation | All Part I rows remain after v1→v2 migration with unchanged IDs/values; new schema exists | Original guest list visible after upgrade; **3 guest records** shown | **Partial** — compare pre-upgrade IDs/values and count from original app copy; verify v2 tables/schema |
| T2 — Parent/child creation | Two cards in one folder, one in another; correct counts and isolation | **Playing Cards: 2** (`Ace of Hearts`, `King of Spades` initially); **Favorites: 1** (`Queen of Diamonds`). All appeared only in the assigned folder | **UI pass** — capture actual folder/card IDs for complete evidence |
| T3 — Edit identity/cancel | Edit one card only; canceled edit makes no database changes | Renamed `Ace of Hearts` to `Ace of Hearts Updated`; notes changed to `Updated during T3 testing`. Canceled edit of `King of Spades`; it remained unchanged. Folder count remained 2 | **UI pass** — capture row ID / query result if available |
| T4 — Restart persistence | Rows, IDs, values, counts survive force-stop and relaunch with no duplicates | User confirmed all folders, cards, edited values, and 3 roster records survived restart with no duplicates | **UI pass** — save post-restart screenshot; verify IDs if available |
| T5 — Delete behavior | Cancel keeps folder/cards; confirm deletes folder and its child rows; other rows unaffected | Disposable `T5 Test Folder` containing two cards survived cancellation and disappeared after confirmation; other folders unchanged | **UI pass** — query `cards` by deleted folder ID to establish actual cascade |
| T6 — Failure/image fallback | Blank title not saved; null/invalid image shows placeholder; existing records unaffected | User confirmed blank title validation, diamond suit fallback for blank/invalid URL, and unchanged folder counts (2 and 1) | **UI pass** |

### Suggested read-only SQL evidence (run against the app's database safely)

```sql
PRAGMA user_version;
PRAGMA foreign_keys;
SELECT _id, name, age FROM my_table ORDER BY _id;
SELECT id, name, created_at FROM folders ORDER BY id;
SELECT id, folder_id, title, suit, notes, image_ref FROM cards ORDER BY id;
SELECT f.id, f.name, COUNT(c.id) AS card_count
FROM folders AS f
LEFT JOIN cards AS c ON c.folder_id = f.id
GROUP BY f.id, f.name ORDER BY f.id;
PRAGMA foreign_key_list(cards);
```

For T5, the deleted folder ID must be recorded **before** deletion. After deletion, query `SELECT id FROM cards WHERE folder_id = <actual_deleted_folder_id>;` and record the zero-row result. This is a read-only check; do not re-run the destructive test on real data. SQLite `PRAGMA foreign_keys` reports a connection-specific setting, so verify enforcement on the actual app connection or with a controlled disposable test.

### Evidence files

- `evidence/T1_before.png`: original Part I install **before** migration (3 guest records if that was also the original count); use the preserved app copy, not a recreated screenshot.
- `evidence/T2_cards.png`: current folder list with 2 cards in Playing Cards and 1 in Favorites (and optionally separate card-list screenshots).
- `evidence/T4_after.png`: the folder list after a cold restart showing persistent counts.
- `evidence/analysis_output.txt`: verbatim output from `flutter analyze`, including any warnings/errors.
- Optional: `evidence/sql_verification.txt`: actual read-only query output and real record IDs.

### Known limitations / pending verification

- Full T1 pre-/post-migration IDs and values comparison not yet documented.
- T2/T3/T4 database primary keys and T5 cascade child-row query not yet documented.
- Fresh database creation path not yet independently verified.
- `flutter analyze` output, release APK build/install/smoke test, and screenshots have not yet been attached to this README package.
- Remote image URLs require network access; the suit symbol remains the fallback.

### Rubric evidence map

| Rubric area | Where to inspect |
|---|---|
| Schema & data preservation | `lib/database_helper.dart`, `lib/schema.dart`, T1, SQL evidence |
| Models, repository & CRUD | `lib/models.dart`, `lib/repository.dart`, T2/T3/T5 |
| Image handling & usability | `lib/screens.dart`, T6 |
| Testing & evidence | This matrix, `evidence/` folder, release APK smoke-test notes |
| Reflection & AI Lab | Separately submitted named critical-thinking DOCX |
| README & delivery | This README, `pubspec.yaml`, `pubspec.lock`, `github_link.txt`, APK |

### Submission checklist

- [ ] Enter pathway, Flutter version, and device details.
- [ ] Capture authentic T1 pre-upgrade screenshot and compare actual values/IDs.
- [ ] Save T2 and post-restart T4 screenshots with required names.
- [ ] Run and save `flutter analyze` output.
- [ ] Perform read-only schema/ID/cascade checks and log actual results.
- [ ] Test fresh-install path using disposable emulator/profile.
- [ ] Commit full Flutter project and evidence to accessible GitHub repository.
- [ ] Put repository URL in `github_link.txt`.
- [ ] Build, install, and smoke-test the exact release APK; rename `Activity09_Lastname_Firstname.apk`.
- [ ] Complete `Lastname_Firstname_CriticalThinking.docx`, including reflection, AI Lab, and AI-use disclosure.
- [ ] Upload all three required files to the appropriate course folder and verify uploads.

### Assistance disclosure

Draft README organization and test documentation were prepared with ChatGPT (OpenAI, GPT-6). The app behavior recorded here comes from the student's reported manual testing; additional technical verification and written reflection remain the student's responsibility.
