import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fluxshare/main.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('offers local conversion without requiring cloud configuration', (tester) async {
    await tester.pumpWidget(const FluxShareApp(supabase: null));

    expect(find.text('Convert files. Share them securely.'), findsOneWidget);
    expect(
      find.textContaining('Local conversion is ready.'),
      findsOneWidget,
    );
    expect(find.text('Local mode'), findsOneWidget);
  });
}
