import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'package:stateful_data/stateful_data_flutter.dart';

part 'quote_state.dart';

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



/* Without Sateful_data your cubit would look something like this

class QuoteCubit extends Cubit<QuoteState> {
  QuoteCubit() : super(const QuoteInitial()) {
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    final prev = switch (state) {
      QuoteLoaded(quote: final q) => q,
      QuoteFailure(previous: final q) => q,
      QuoteLoading(previous: final q) => q,
      _ => null,
    };

    if (state is QuoteLoading) return;

    emit(QuoteLoading(previous: prev));

    try {
      final response = await http.get(Uri.parse('https://api.github.com/zen'));

      if (response.statusCode == 200) {
        final text = response.body.trim();
        if (text.isEmpty) {
          emit(const QuoteEmpty());
        } else {
          emit(QuoteLoaded(text));
        }
      } else {
        emit(QuoteFailure('HTTP ${response.statusCode}', previous: prev));
      }
    } catch (e) {
      emit(QuoteFailure(e.toString(), previous: prev));
    }
  }

  Future<void> refreshQuote() => _loadQuote();
}


 */