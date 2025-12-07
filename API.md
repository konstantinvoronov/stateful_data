# stateful_data – API Reference (v0.0.1)

This document describes the public API surface of the **stateful_data** package as of version **0.0.1**.

The package defines:

- A generic sealed lifecycle type: [`StatefulData<T, E>`](#statefuldatat-e)
- Concrete lifecycle variants:
  - [`Uninitialized<T, E>`](#uninitializedt-e)
  - [`Loading<T, E>`](#loadingt-e)
  - [`Empty<T, E>`](#emptyt-e)
  - [`Ready<T, E>`](#readyt-e)
  - [`Dirty<T, E>`](#dirtyt-e)
  - [`Updating<T, E>`](#updatingt-e)
  - [`Failure<T, E>`](#failuret-e)
- An extensible marker hierarchy for “dirty” reasons:
  - [`DirtyKind`](#dirtykind)
  - [`EditedDirty`](#editeddirty)
  - [`ValidatedDirty`](#validateddirty)
  - [`CachedDirty`](#cacheddirty)
- Recommended type aliases (in your app code):
  - `typedef AppStatefulData<T> = StatefulData<T, AppError>;`
  - `typedef StatefulDataAnyError<T> = StatefulData<T, Object>;`

---

## StatefulData<T, E>

```dart
sealed class StatefulData<T, E extends Object> {
  const StatefulData([this.value]);
  final T? value;

  /// Collapse the full lifecycle into two branches:
  /// - "we have a usable value"   -> onValue
  /// - "we do not have a value"   -> onNoValue
  R either<R>(
    R Function(T value) onValue,
    R Function(E? failure) onNoValue,
  );

  /// Returns the best available usable value, or null if none.
  ///
  /// Priority (conceptual):
  /// - Ready / Updating / Dirty -> current value
  /// - Loading(prev)            -> prev
  /// - Failure(prev)            -> prev
  /// - Uninitialized / Empty    -> null
  T? valueOrNull();

  /// Transition to [Loading], carrying the best available previous value
  /// (if any) for optimistic UI.
  Loading<T, E> toLoading({
    Future<bool>? future,
    Completer<T>? completer,
  });

  /// Transition to [Updating], keeping previous context for optimistic UI.
  Updating<T, E> toUpdating(
    T newValue, {
      Future<bool>? future,
      Completer<T>? completer,
    });

  /// Transition to [Dirty], marking this value as locally modified or cached.
  Dirty<T, E> toDirty(
    T newValue, {
      DirtyKind kind = const EditedDirty(),
      DateTime? dirtyAt,
    });

  /// Transition to [Failure], preserving the best previous value if any.
  Failure<T, E> toFailure(E failure);
}
```

### Semantics

- `T` – the value type (e.g. `User`, `String`, `List<Post>`).
- `E` – the error type (e.g. `AppError`, `Exception`, `String`).
- `value` – a convenience field carrying “current” value in some states.
  - In variants that don’t carry a real value (like `Uninitialized`, `Empty`), `value` is `null`.
  - In `Ready`, `Dirty`, `Updating` it equals the current `T`.

The **recommended way** to use this type is through:

- **explicit pattern matching** with `switch` on the sealed hierarchy, and/or
- the `either` helper when you conceptually only care about “value or no value”.

---

## Uninitialized<T, E>

```dart
/// No attempt to load yet (initial state).
final class Uninitialized<T, E extends Object> extends StatefulData<T, E> {
  const Uninitialized() : super();
}
```

### Semantics

- Starting state before any load attempts.
- Typically used as the initial state in controllers/BLoCs.
- `value` is always `null`.

---

## Loading<T, E>

```dart
/// A load from backend/storage is in progress.
final class Loading<T, E extends Object> extends StatefulData<T, E> {
  final T? prev;
  final Future<bool>? future;
  final Completer<T>? completer;

  Loading({
    StatefulData<T, E>? previous,
    this.future,
    this.completer,
  })  : prev = switch (previous) {
          Ready<T, E>(value: final v) => v,
          Updating<T, E>(value: final v, prev: final p) => v ?? p,
          Loading<T, E>(prev: final v) => v,
          Dirty<T, E>(value: final v, prev: final p) => v ?? p,
          Failure<T, E>(prev: final p) => p,
          _ => previous?.value,
        },
        super(previous?.value);
}
```

### Semantics

- Represents an ongoing **load** from backend or storage.
- `prev` carries the best-known previous value if any; can be `null`.
- Use `toLoading()` on any `StatefulData<T, E>` to compute `prev` correctly.

Typical usage:

```dart
emit(state.copyWith(user: state.user.toLoading()));
```

---

## Empty<T, E>

```dart
/// The resource exists but is empty (e.g. empty list / no data).
final class Empty<T, E extends Object> extends StatefulData<T, E> {
  const Empty() : super();
}
```

### Semantics

- Explicitly represents “empty but valid” (e.g., empty list, no results).
- Distinct from `Uninitialized` and from “no value because of failure”.
- `value` is always `null` (by design).

---

## Ready<T, E>

```dart
/// Successfully loaded value, ready for consumption.
final class Ready<T, E extends Object> extends StatefulData<T, E> {
  final T value;
  const Ready(this.value) : super(value);
}
```

### Semantics

- Represents a successfully loaded, “good” value.
- `value` is non-null and equals `this.value`.

---

## Updating<T, E>

```dart
/// An update to backend is in progress (PATCH/PUT/POST).
final class Updating<T, E extends Object> extends StatefulData<T, E> {
  final T value;
  final T? prev;
  final Future<bool>? future;
  final Completer<T>? completer;

  Updating(
    this.value, {
      StatefulData<T, E>? previous,
      this.future,
      this.completer,
    })  : prev = switch (previous) {
          Ready<T, E>(value: final v) => v,
          Updating<T, E>(value: final v, prev: final p) => v ?? p,
          Loading<T, E>(prev: final v) => v,
          Dirty<T, E>(value: final v, prev: final p) => v ?? p,
          Failure<T, E>(prev: final p) => p,
          _ => previous?.value,
        },
        super(value);
}
```

### Semantics

- Represents an **ongoing update** of a value **to** the backend (e.g. save or patch).
- `value` – the value being sent.
- `prev` – previous confirmed or best-known value.
- Use `toUpdating(newValue)` on any `StatefulData<T,E>` to transition safely.

Typical usage:

```dart
final current = state.user;
emit(state.copyWith(user: current.toUpdating(userToSave)));
```

---

## Failure<T, E>

```dart
/// The last operation failed.
final class Failure<T, E extends Object> extends StatefulData<T, E> {
  final E failure;
  final T? prev;

  Failure(
    this.failure, [
      StatefulData<T, E>? previous,
    ])  : prev = switch (previous) {
          Ready<T, E>(value: final v) => v,
          Updating<T, E>(value: final v) => v,
          Loading<T, E>(prev: final v) => v,
          Dirty<T, E>(value: final v, prev: final p) => v ?? p,
          Failure<T, E>(prev: final p) => p,
          _ => previous?.value,
        },
        super(previous?.value);
}
```

### Semantics

- Represents a **failed** operation (load, update, etc.).
- `failure` carries the error `E` (e.g. `AppError`).
- `prev` carries the last usable value if any; can be `null`.

Use `toFailure(error)` on any `StatefulData<T, E>` to construct a `Failure` while preserving as much previous context as possible.

Typical usage:

```dart
name = name.toFailure(
  ValidationError('Must be at least 5 characters'),
);
```

---

## Dirty<T, E>

```dart
/// Local edits or cached data that differ from the last confirmed backend state.
final class Dirty<T, E extends Object> extends StatefulData<T, E> {
  final DateTime? dirtyAt;
  final DirtyKind kind;
  final T? prev;
  final T value;

  Dirty(
    this.value, {
      StatefulData<T, E>? previous,
      this.kind = const EditedDirty(),
      this.dirtyAt,
    })  : prev = switch (previous) {
          Ready<T, E>(value: final v) => v,
          Updating<T, E>(value: final v, prev: final p) => v ?? p,
          Loading<T, E>(prev: final v) => v,
          Dirty<T, E>(value: final v, prev: final p) => v ?? p,
          Failure<T, E>(prev: final p) => p,
          _ => previous?.value,
        },
        super(value);
}
```

### Semantics

- Represents **local changes** or **cached data** that differ from the last confirmed backend state.
- `value` – the current edited/cached value.
- `prev` – previous confirmed or best-known value.
- `kind` – a `DirtyKind` enum-like marker describing *why* it is dirty.
- `dirtyAt` – optional timestamp when it became dirty.

Use `toDirty(newValue, kind: ...)` on any `StatefulData<T, E>` to mark it as dirty.

Typical usage:

```dart
// user edited:
name = name.toDirty('New name');

// after validation:
name = name.toDirty(
  'Validated name',
  kind: const ValidatedDirty(),
);
```

---

## DirtyKind

```dart
/// Marker base class for kinds of “dirty” data.
abstract class DirtyKind {
  const DirtyKind();
}
```

### Semantics

- Abstract marker type describing **why** data is dirty.
- You can extend this in your app for domain-specific meanings.

---

## EditedDirty

```dart
/// Locally edited, not yet saved/confirmed.
class EditedDirty extends DirtyKind {
  const EditedDirty();
}
```

- Default `DirtyKind` used by `toDirty()` when no kind is provided.
- Indicates “user changed this locally but we haven’t confirmed/saved it yet”.

---

## ValidatedDirty

```dart
/// Locally edited, passed validation, not yet saved/confirmed.
class ValidatedDirty extends DirtyKind {
  const ValidatedDirty();
}
```

- Indicates the value is **locally valid**, but still not confirmed by backend.

---

## CachedDirty

```dart
/// Value comes from a cache, not yet confirmed by backend in this session.
class CachedDirty extends DirtyKind {
  const CachedDirty();
}
```

- Intended for “cached-first” flows:
  - Repository returns `Dirty(value, kind: CachedDirty())`.
  - Controller shows cached value, then decides whether to refresh from backend.

---

## Recommended app-level extensions

These are **not** part of the core package but are recommended patterns for your app.

### App-level typedefs

```dart
typedef AppStatefulData<T> = StatefulData<T, AppError>;
typedef StatefulDataAnyError<T> = StatefulData<T, Object>;
```

### App-level error type

```dart
sealed class AppError {
  final String message;
  const AppError(this.message);
}

class ValidationError extends AppError {
  const ValidationError(String message) : super(message);
}

class NetworkError extends AppError {
  const NetworkError(String message) : super(message);
}
```

### Example usage

```dart
// Initial:
AppStatefulData<String> name = const Uninitialized<String, AppError>();

// Loading:
name = name.toLoading();

// Ready:
name = Ready<String, AppError>('John');

// Edit:
name = name.toDirty('Jon');

// Validation error:
name = name.toFailure(
  const ValidationError('Must be at least 3 characters'),
);
```

You can also build your own helpers on top of `either(...)`, for example a `toEither`, `toResult`, or `valueOrThrow` in your own app, without adding external dependencies to `stateful_data` itself.

---

This reference will evolve as the library grows. For now it documents the **core lifecycle types** and their semantics so you can confidently adopt the StatefulData pattern across repositories, controllers/BLoCs, and UI.
