import 'package:flutter/material.dart';
import 'package:stateful_data/stateful_data.dart';


/// Called when we have a value to show.
/// [inProgress] is true when we are in a loading/updating state but can still show [value].
/// [error] is provided when we are in a failure state but still have a previous value.
typedef StatefulValueBuilder<T, E extends Object> = Widget Function(
    T value,
    bool inProgress, {
    E? error,
    });

/// Called when we are in a failure state and there is no previous value
/// (or you want a dedicated error UI).
typedef StatefulFailureBuilder<T, E extends Object> = Widget Function(
    T? value,
    E error,
    );

/// Shimmer / skeleton / placeholder while there is no value yet (or initial load).
typedef ShimmerBuilder = Widget Function();

/// Builds UI based on a [StatefulData<T, E>] lifecycle.
///
/// Typical usage:
///
/// ```dart
/// StatefulDataBuilder<String, AppError>(
///   data: state.name,
///   shimmer: () => const NameShimmer(),
///   builder: (value, inProgress, {error}) => NameField(
///     initialValue: value,
///     isLoading: inProgress,
///     errorText: error?.message,
///   ),
/// )
/// ```
class StatefulDataBuilder<T, E extends Object> extends StatelessWidget {
  final StatefulData<T, E> data;
  final ShimmerBuilder shimmer;
  final StatefulValueBuilder<T, E> builder;
  final StatefulFailureBuilder<T, E>? failureBuilder;
  final Widget Function()? emptyBuilder;

  const StatefulDataBuilder({
    super.key,
    required this.data,
    required this.shimmer,
    required this.builder,
    this.failureBuilder,
    this.emptyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final d = data;

    return switch (d) {
    // Loading with previous value → show value with progress
      Loading<T, E>(prev: final T v?) => builder(v, true),

    // No value yet, still loading/uninitialized → shimmer
      Uninitialized<T, E>() || Loading<T, E>() => shimmer(),

    // Failure with previous value → show value, but pass error
      Failure<T, E>(prev: final T v?, failure: final e) when v != null =>
          builder(v, false, error: e),

    // Failure without usable previous value → dedicated failure UI or nothing
      Failure<T, E>(prev: final v, failure: final e) =>
      failureBuilder?.call(v, e) ?? const SizedBox.shrink(),

    // Updating → treat as in-progress with latest value
      Updating<T, E>(value: final v) =>
          builder(v, true),

    // Dirty / Ready → normal UI with value
      Dirty<T, E>(value: final v, kind: _) ||
      Ready<T, E>(value: final v) =>
          builder(v, false),

    // Empty → custom empty UI or nothing
      Empty<T, E>() =>
      emptyBuilder?.call() ?? const SizedBox.shrink(),
    };
  }
}

/// Same as [StatefulDataBuilder], but takes a [Stream] of [StatefulData].
///
/// The initial state is treated as [Uninitialized] until first data arrives.
class StatefulDataStreamBuilder<T, E extends Object> extends StatelessWidget {
  final Stream<StatefulData<T, E>> stream;
  final ShimmerBuilder shimmer;
  final StatefulValueBuilder<T, E> builder;
  final StatefulFailureBuilder<T, E>? failureBuilder;
  final Widget Function()? emptyBuilder;

  const StatefulDataStreamBuilder({
    super.key,
    required this.stream,
    required this.shimmer,
    required this.builder,
    this.failureBuilder,
    this.emptyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StatefulData<T, E>>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const Uninitialized();

        return StatefulDataBuilder<T, E>(
          data: data,
          shimmer: shimmer,
          builder: builder,
          failureBuilder: failureBuilder,
          emptyBuilder: emptyBuilder,
        );
      },
    );
  }
}
