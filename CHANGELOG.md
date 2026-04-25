# Changelog

All notable changes to the **stateful_data** package will be documented in this file.


## 1.0.6 — Updated StatefulFailureBuilder

- Added futureValueOrNull - This is useful for cache resolution: if an item is already loading, callers receive the same in-progress Future instead of starting a duplicate request or receiving null. 

## 1.0.5 — Updated StatefulFailureBuilder

- BREAKING: classes Loading and Updating takes Future<T>? future intead of Future<bool>? future
- BREAKING: Helpers toUpdating and toLoading no accepts Future<T>? future intead of Future<bool>? future

## 1.0.3 — Simplified example

- Updated example: moved all separate files into a single `main.dart` for easier copy–paste and experimentation.

## 1.0.2 — Examples

- Updated example to follow pub.dev convention.

## 1.0.1 — Examples & Flutter usage helpers

- Added usage examples demonstrating common lifecycle scenarios.
- Update README with guidance on:
    - recommended architectural usage patterns
    - value vs no-value lifecycle semantics
    - failure & optimistic-update handling
- Introduced `.statefulBuilder()` sugar extensions for widgets and streams.

## 1.0.0 — Initial Release

- Introduced the **StatefulData** declarative data-lifecycle pattern.
- Implemented the core lifecycle states:
    - `Uninitialized`
    - `Empty`
    - `Loading`
    - `Updating`
    - `Dirty`
    - `Ready`
    - `Failure`
- Added core API for transitioning between states.
- Provided foundational documentation and README.
- Established repository structure and issue tracker.
