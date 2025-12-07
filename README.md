# stateful_data

A small Flutter/Dart package that introduces a **declarative lifecycle type** for values in BLoC-style state management.
Created by **Konstantin Voronov**.

The library hides a lot of corner-case logic under the hood and gives you a **bullet-proof, readable scaffold** per layer. It promotes:

- clear error handling,
- explicit value state transitions,
- separation of concerns across Clean Architecture layers.

`stateful_data` gives you a single sealed type:

```dart
StatefulData<T, E>
```

that replaces Traditional BLoC state patterns like:

- nullable fields
- ad-hoc flags (`isLoading`, `hasError`, `isValid`, etc.)
- inconsistent async handling
- implicit states (“is this loaded or not?”)
- forgotten edge cases
- sealed classes where some fields are `null` in some variants and non-null in others


```dart
T? value;
bool isLoading;
bool hasError;
String? errorMessage;
```

with an explicit lifecycle:

- `Uninitialized` – nothing loaded yet
- `Empty` – known to be empty (e.g. empty list)
- `Loading` – loading from backend/storage (optionally with previous value)
- `Ready` – successfully loaded value
- `Dirty` – locally edited / cached / not yet validated
- `Updating` – sending updates to backend
- `Failure` – last operation failed (optionally with previous value)

Every value wrapped in `StatefulData` is always in **exactly one** of these states.


It’s **just a data type**, so it works with:

- BLoC / Cubit
- Riverpod
- ValueNotifier
- any other state management


## 🧱 Core types

```dart
sealed class StatefulData<T, E extends Object> {
  const StatefulData([this.value]);
  final T? value;

  // Collapse “full lifecycle” → “value or no value”
  R either<R>(
    R Function(T value) onValue,
    R Function(E? failure) onNoValue,
  );

  // Get best usable value or null (built on top of either)
  T? valueOrNull();

  Loading<T, E> toLoading({
    Future<bool>? future,
    Completer<T>? completer,
  });

  Updating<T, E> toUpdating(
    T newValue, {
      Future<bool>? future,
      Completer<T>? completer,
    });

  Dirty<T, E> toDirty(
    T newValue, {
      DirtyKind kind = const EditedDirty(),
      DateTime? dirtyAt,
    });

  Failure<T, E> toFailure(E failure);
}

final class Uninitialized<T, E extends Object> extends StatefulData<T, E> { /* ... */ }
final class Loading<T, E extends Object>       extends StatefulData<T, E> { /* ... */ }
final class Empty<T, E extends Object>         extends StatefulData<T, E> { /* ... */ }
final class Ready<T, E extends Object>         extends StatefulData<T, E> { /* ... */ }
final class Updating<T, E extends Object>      extends StatefulData<T, E> { /* ... */ }
final class Failure<T, E extends Object>       extends StatefulData<T, E> { /* ... */ }
final class Dirty<T, E extends Object>         extends StatefulData<T, E> { /* ... */ }
```

---


---

## 🧩 `Dirty` and extensible `DirtyKind`

`Dirty` represents “local edits or cached data” that differ from the last confirmed backend state.  
The **reason** or **kind** of “dirty” is extensible:

```dart
abstract class DirtyKind {
  const DirtyKind();
}

class EditedDirty extends DirtyKind {
  const EditedDirty(); // locally edited, not yet saved
}

class ValidatedDirty extends DirtyKind {
  const ValidatedDirty(); // passed local validation
}

class CachedDirty extends DirtyKind {
  const CachedDirty(); // comes from cache, not yet confirmed by backend
}

// You can extend in your app:
class ConflictDirty extends DirtyKind {
  const ConflictDirty(); // e.g. server conflict that user must resolve
}
```

Example:

```dart
// define you own helper type with your Error processing. for example AppError (down in the examples
typedef AppStatefulData<T> = StatefulData<T, AppError>;

AppStatefulData<String> name = const Ready('Initial');

// User edits:
name = name.toDirty('New value', kind: const EditedDirty());

// After validation:
name = name.toDirty(
  'Valid value',
  kind: const ValidatedDirty(),
);
```

---

## 🧬 Lifecycle in action

A typical flow for a single field:

```dart
// Initial state:
StatefulData<String, AppError> name = const Uninitialized();

// Start loading from backend:
name = name.toLoading();

// Or: if you already have cached value:
name = Dirty<String, AppError>(
  'John (cached)',
  kind: const CachedDirty(),
).toLoading();

// Got result from backend:
name = Ready<String, AppError>('John');

// User edits the value locally:
name = name.toDirty('Jon'); // EditedDirty by default

// Validation fails:
name = name.toFailure(
  const ValidationError('Must be at least 5 characters'),
);

// User fixes and we send update:
name = name.toDirty('Jonathan');

// Mark as “validated but not saved yet”:
name = name.toDirty(
  'Jonathan',
  kind: const ValidatedDirty(),
);

// Start updating backend:
name = name.toUpdating('Jonathan');

// Server accepts → mark as ready:
name = Ready<String, AppError>('Jonathan');

// If a network error happens:
name = name.toFailure(
  const NetworkError('Network error, please try again'),
);
```

---
## 🔧 Simple error handling examples - error type and typedefs

You choose the error type `E` (e.g. `AppError`, `Exception`, `String`).

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



## 🧭 How to use it across layers

The pattern is designed to be used consistently across **Repo → Controller/BLoC → UI**.

### In Repository / Data layer

Return `StatefulData` instead of nullable values or flags:

```dart
Future<AppStatefulData<User>> fetchUser() async {
  try {
    final raw = await api.getUser();

    if (raw == null) {
      return const Empty<User, AppError>();
    }

    return Ready<User, AppError>(raw);
  } on Exception catch (e) {
    return Failure<User, AppError>(
      NetworkError(e.toString()),
    );
  }
}
```

### In Controller / BLoC

Use transitions to move through the lifecycle:

```dart
class UserState {
  final AppStatefulData<User> user;
  const UserState({required this.user});

  factory UserState.initial() =>
      const UserState(user: Uninitialized<User, AppError>());

  UserState copyWith({AppStatefulData<User>? user}) =>
      UserState(user: user ?? this.user);
}

class UserController extends Cubit<UserState> {
  final UserRepository repo;

  UserController(this.repo) : super(UserState.initial());

  Future<void> loadUser() async {
    // 1) Show loading (keep prev value if any):
    emit(state.copyWith(user: state.user.toLoading()));

    // 2) Ask repo:
    final result = await repo.fetchUser();

    // 3) Store exactly what repo returned:
    emit(state.copyWith(user: result));
  }
}
```

If you want a simple “value vs no value” view for UI flags:

```dart
final showSkeleton = state.user.either(
  (value)    => false,           // we have something
  (failure)  => true,            // no value → show skeleton
);
```

### In UI

Use a `switch` on `StatefulData`:

```dart
final userData = context.watch<UserController>().state.user;

return switch (userData) {
  Uninitialized<User, AppError>() ||
  Loading<User, AppError>(prev: null) =>
    const UserShimmer(),

  Loading<User, AppError>(prev: final u?) =>
    UserView(user: u, isRefreshing: true),

  Ready<User, AppError>(value: final u) =>
    UserView(user: u),

  Dirty<User, AppError>(value: final u, kind: _) =>
    UserView(user: u, isEdited: true),

  Updating<User, AppError>(value: final u) =>
    UserView(user: u, isSaving: true),

  Failure<User, AppError>(prev: final u?, failure: final e) when u != null =>
    UserView(user: u, errorBanner: e.message),

  Failure<User, AppError>(prev: null, failure: final e) =>
    ErrorScreen(message: e.message),

  Empty<User, AppError>() =>
    const EmptyUserPlaceholder(),
};
```

No more juggling:

```dart
String? name;
bool isLoadingName;
bool isNameValid;
String? nameError;
```

or giant state classes where fields are `null` only for some subclasses.

Each value is **self-contained** and explicit about its lifecycle.

---

## 🎯 Core philosophy

- **Non-nullable by design**  
  You model *states*, not “maybe null” values.

- **Declarative lifecycle**  
  You describe *what* the data is (uninitialized / loading / ready / dirty / failure),
  not a bunch of flags.

- **Predictable and robust**  
  All states must be consciously handled; the compiler helps you remember them.

- **Slightly more boilerplate → much clearer logic**  
  You pay once in structure and win every day in readability and correctness.

---

## 📦 Installation

```yaml
dependencies:
  stateful_data: ^0.0.1
```

Then:

```dart
import 'package:stateful_data/stateful_data.dart';
```

---

## 📘 Documentation & Sources

- **Repository:** https://github.com/konstantinvoronov/stateful_data
- **Issue Tracker:** https://github.com/konstantinvoronov/stateful_data/issues
- **Homepage:** https://github.com/konstantinvoronov/stateful_data

More docs and layer-specific examples (repositories, controllers, UI) will be added over time.

---

## 🧑‍💻 Author

**Konstantin Voronov**  
Creator of the **StatefulData declarative data-lifecycle pattern** for Flutter BLoC architectures.  
Email: `me@konstantinvoronov.com`

---

## ⭐ Support

If you find this package useful, please consider giving it a ⭐ on GitHub!
