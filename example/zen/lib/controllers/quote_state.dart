part of 'quote_cubit.dart';

typedef AppStatefulData<T> = StatefulData<T, StateError>;

// This looks like a simple “one-value” Cubit, but the benefit of
// `StatefulData` becomes obvious when the same page manages several
// independent quotes. Each field keeps its own lifecycle instead of
// exploding the Bloc into many combined states.
//
// The Bloc state itself only has to represent the *general* UI state
// of the screen, while the lifecycle of each individual value is
// handled by its own `StatefulData<T, E>` field.

class QuoteState extends Equatable {
  final AppStatefulData<String> quote;

  const QuoteState({this.quote = const Uninitialized()});

  QuoteState copyWith({
    AppStatefulData<String>? quote,
  }) {
    return QuoteState(quote: quote ?? this.quote,);
  }

  @override
  List<Object?> get props => [quote];
}


/* Without Sateful_data your state would look something like this
*
*
*
*  sealed class QuoteState extends Equatable {
*    const QuoteState();
*
*    @override
*    List<Object?> get props => [];
*  }

*  /// No attempt to load yet / first build.
*  final class QuoteInitial extends QuoteState {
*    const QuoteInitial();
*  }

*  /// Loading, optionally with a previous quote for optimistic UI.
*  final class QuoteLoading extends QuoteState {
*    final String? previous;

*    const QuoteLoading({this.previous});

*    @override
*    List<Object?> get props => [previous];
*  }

*  /// Successfully loaded quote.
*  final class QuoteLoaded extends QuoteState {
*    final String quote;

*    const QuoteLoaded(this.quote);

*    @override
*    List<Object?> get props => [quote];
*  }

*  /// Loaded successfully, but response is empty.
*  final class QuoteEmpty extends QuoteState {
*    const QuoteEmpty();
*  }

*  /// Last operation failed, optionally carrying last known quote.
*  final class QuoteFailure extends QuoteState {
*    final String message;
*    final String? previous;

*    const QuoteFailure(this.message, {this.previous});

*    @override
*    List<Object?> get props => [message, previous];
*  }
*
*/
