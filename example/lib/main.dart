import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stateful_data/stateful_data_flutter.dart';
import 'package:http/http.dart' as http;


// stateful_data is a deliberately “vanilla” approach.
// No generated code, no magic framework behaviour — just a small
// lifecycle type (`StatefulData<T, E>`) plus a couple of simple helpers.
//
// This example is meant to demonstrate the difference in boilerplate
// between the stateful_data approach and a generic sealed Bloc state approach.

// Associate E with StateError or another error type used in your app.
typedef AppStatefulData<T> = StatefulData<T, StateError>;


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'stateful_data example app',
      home: const QuoteScreen(),
    );
  }
}

/// QuoteScreen - Displays a quote from Zen (https://api.github.com/zen) and refreshes it on button tap,
/// using StatefulData to declaratively handle all possible states.
class QuoteScreen extends StatelessWidget {
  const QuoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
        create: (_) => QuoteCubit(),
        child: BlocBuilder<QuoteCubit, QuoteState>(
            builder: (BuildContext context, QuoteState state) {
              final cubit = context.read<QuoteCubit>();

              return Scaffold(
                appBar  : AppBar(title: const Text('Stateful_data example'),),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      state.quote.statefulBuilder(
                        shimmer: () => const CircularProgressIndicator(),
                        builder: (value, inProgress, {StateError? error}) =>
                            Quote(quote: value, inProgress: inProgress, error: error),
                        failureBuilder: (StateError error) =>
                            Text('Failed to get initial value. ${error.toString()}'),
                        emptyBuilder: () =>
                        const Text('No quote available.'),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: cubit.refreshQuote,
                        child: const Text('Update quote'),
                      ),
                    ]),
                  ),
                ),
              );
            })
    );
  }
}

// Bloc remains Bloc, the state remains a normal data object.
// The only thing that changes is that each value gets its own
// explicit lifecycle instead of inflating the Bloc into many
// ad-hoc sealed states.

class QuoteCubit extends Cubit<QuoteState> {
  QuoteCubit() : super(QuoteState()) {
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    if(state.quote is Loading || state.quote is Updating) return;

    emit(state.copyWith(quote: state.quote.toLoading()));

    try {
      final response = await http.get(Uri.parse('https://api.github.com/zen'));

      if (response.statusCode == 200) {
        final text = response.body.trim();
        if (text.isEmpty) {
          emit(state.copyWith(quote: Empty()));
        } else {
          emit(state.copyWith(quote: Ready(text)));
        }
      } else {
        emit(state.copyWith(quote: state.quote.toFailure(StateError('HTTP ${response.statusCode}'),)));
      }
    } catch (e) {
      emit(state.copyWith(quote: state.quote.toFailure(StateError(e.toString()),)));
    }
  }

  Future<void> refreshQuote() => _loadQuote();
}

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

class Quote extends StatelessWidget{
  final String quote;
  final bool inProgress;
  final StateError? error;

  const Quote({super.key, required this.quote, required this.inProgress, this.error});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Text(quote, textAlign: TextAlign.center, style: Theme
            .of(context)
            .textTheme
            .titleLarge,),
        if (inProgress)
          const CircularProgressIndicator(),
      ]),
      const SizedBox(height: 16),
      if (error != null)
        Text(error.toString(),
          textAlign: TextAlign.center, style: TextStyle(color: Theme
              .of(context)
              .colorScheme
              .error,),
        ),
    ]);
  }
}