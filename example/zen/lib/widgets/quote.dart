
import 'package:flutter/material.dart';

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