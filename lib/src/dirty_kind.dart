// lib/src/dirty_kind.dart

/// Base class for describing why a value is considered "dirty".
///
/// Built-in kinds:
/// - [EditedDirty] — value was modified locally (unsaved/unsynced).
/// - [ValidatedDirty] — value comes from cache and may be stale.
/// - [CachedDirty] — value comes from cache and may be stale.
///
/// Apps may extend this class to add project-specific kinds:
///
///   class ConflictDirty extends DirtyKind {
///     const ConflictDirty();
///   }
abstract class DirtyKind {
  const DirtyKind();
}

/// The value was modified locally and is not yet validated or saved.
class EditedDirty extends DirtyKind {
  const EditedDirty();
}

/// The value was modified locally and was validated but not yet started uploading / saved.
class ValidatedDirty extends DirtyKind {
  const ValidatedDirty();
}

/// The value comes from cache and may not reflect the current backend state.
class CachedDirty extends DirtyKind {
  const CachedDirty();
}
