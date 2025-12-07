// lib/src/stateful_data.dart
import 'dart:async';

import 'dirty_kind.dart';

/// StatefulData - declarative lifecycle wrapper for a value of type [T].
///
/// [E] is the error type (e.g. AppFailure, Exception, String, etc.).
///
/// In your app you can define a shorthand like:
///   // typedef StatefulDataAnyError<T> = StatefulData<T, Object>;
///
/// The union of subclasses models the full lifecycle:
/// - Uninitialized  – never loaded
/// - Loading        – loading from backend/storage
/// - Empty          – known to be empty
/// - Ready          – successfully loaded value
/// - Dirty          – locally edited / cached value
/// - Updating       – sending updates to backend
/// - Failure        – last operation failed
sealed class StatefulData<T, E extends Object> {
  final T? value;
  const StatefulData([this.value]);


  /// Collapse the full lifecycle into just two branches:
  /// - "we have a usable value"     -> [onValue]
  /// - "we do not have a value"     -> [onNoValue]
  ///
  /// Usable-value states (onValue):
  /// - Ready(value)
  /// - Dirty(value, kind)
  /// - Updating(value)
  /// - Loading(prev != null)
  /// - Failure(prev != null)        // last known good value
  ///
  /// No-value states (onNoValue):
  /// - Failure(failure, prev == null)      -> onNoValue(failure)
  /// - Uninitialized / Empty / Loading(no prev) -> onNoValue(null)
  ///
  /// This is a *structural* view of your lifecycle: “do I currently have
  /// something I can treat as a value or not?”.
  ///
  /// How you *use* it is up to the layer (repo/controller/UI). Recommended:
  /// - repos: still prefer explicit transforms or withDomainDefault(...)
  /// - controllers: good place to build UI flags (showSkeleton, hasError, etc.)
  /// - UI: should usually consume higher-level values/flags, not call value() directly.
  R either<R>(
      R Function(T value) onValue,
      R Function(E? failure) onNoValue,
      ) {
    final d = this;
    return switch (d) {
      Dirty<T, E>(value: final v, kind: _) ||
      Updating<T, E>(value: final v) ||
      Loading<T, E>(prev: final v?) ||
      Failure<T, E>(failure: final _, prev: final v?) ||
      Ready<T, E>(value: final v)  => onValue(v),

    // failure with no previous usable value
      Failure<T, E>(failure: final f, prev: null) =>
          onNoValue(f),

    // no usable value at all
      Uninitialized<T, E>() ||
      Empty<T, E>() ||
      Loading<T, E>(prev: null) =>
          onNoValue(null),
    };
  }

  /// Returns the best available usable value, or null if none.
  ///
  /// Priority:
  /// - Ready / Updating / Dirty -> current value
  /// - Loading(prev)            -> prev
  /// - Failure(prev)            -> prev
  /// - Uninitialized / Empty    -> null
  T? valueOrNull() {
    return either<T?>(
          (v) => v,
          (_) => null,
    );
  }

  /// Transition to [Loading], carrying the best available previous value.
  Loading<T, E> toLoading({
    Future<bool>? future,
    Completer<T>? completer,
  }) {
    return Loading(
      previous: this,
      future: future,
      completer: completer,
    );
  }

  /// Transition to [Updating], keeping previous context for optimistic UI.
  Updating<T, E> toUpdating(
      T newValue, {
        Future<bool>? future,
        Completer<T>? completer,
      }) {
    return Updating(
      newValue,
      previous: this,
      future: future,
      completer: completer,
    );
  }

  /// Transition to [Dirty], marking this value as locally modified or cached.
  Dirty<T, E> toDirty(
      T newValue, {
        DirtyKind kind = const EditedDirty(),
        DateTime? dirtyAt,
      }) {
    return Dirty(
      newValue,
      previous: this,
      kind: kind,
      dirtyAt: dirtyAt,
    );
  }

  /// Transition to [Failure], preserving the best previous value if any.
  Failure<T, E> toFailure(E failure) {
    return Failure(
      failure,
      this,
    );
  }
}

/// No attempt to load yet (initial state).
final class Uninitialized<T, E extends Object> extends StatefulData<T, E> {
  const Uninitialized() : super();
}

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

/// The resource exists but is empty (e.g. empty list / no data).
final class Empty<T, E extends Object> extends StatefulData<T, E> {
  const Empty() : super();
}

/// Successfully loaded value, ready for consumption.
final class Ready<T, E extends Object> extends StatefulData<T, E> {
  final T value;
  const Ready(this.value) : super(value);
}

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
