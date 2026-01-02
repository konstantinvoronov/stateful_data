import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stateful_data/stateful_data_flutter.dart';
import 'package:stateful_data_example/widgets/quote.dart';
import 'controllers/quote_cubit.dart';

// stateful_data is a deliberately “vanilla” approach.
// No generated code, no magic framework behaviour — just a small
// lifecycle type (`StatefulData<T, E>`) plus a couple of simple helpers.
//
// This example is meant to demonstrate the difference in boilerplate
// between the stateful_data approach and a generic sealed Bloc state approach.


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
                appBar: AppBar(title: const Text('Stateful_data example'),),
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

/* Without Sateful_data your screen would look something like this

class QuoteScreen extends StatelessWidget {
  const QuoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QuoteCubit(),
      child: Scaffold(
        appBar: AppBar(title: const Text('sealed state example')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BlocBuilder<QuoteCubit, QuoteState>(
                  builder: (context, state) {
                    return switch (state) {
                      QuoteInitial() ||
                      QuoteLoading(previous: null) =>
                        const CircularProgressIndicator(),

                      QuoteLoading(previous: final prev?) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Quote(
                            quote: prev,
                            inProgress: true,
                            error: null,
                          ),
                          const SizedBox(height: 16),
                          const CircularProgressIndicator(),
                        ],
                      ),

                      QuoteLoaded(quote: final q) => Quote(
                        quote: q,
                        inProgress: false,
                        error: null,
                      ),

                      QuoteEmpty() => const Text('No quote available.'),

                      QuoteFailure(message: final msg, previous: final prev) =>
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Failed to get quote: $msg'),
                            if (prev != null) ...[
                              const SizedBox(height: 8),
                              Text('Last value: $prev'),
                            ],
                          ],
                        ),
                    };
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: context.read<QuoteCubit>().refreshQuote,
                  child: const Text('Update quote'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


 */