import 'package:flutter_test/flutter_test.dart';
import 'package:ryu/core/utils/duration_formatter.dart';
import 'package:ryu/core/utils/lrc_parser.dart';

void main() {
  test('DurationFormatter formats minutes and hours properly', () {
    expect(DurationFormatter.format(const Duration(seconds: 65)), '1:05');
    expect(
      DurationFormatter.format(const Duration(hours: 1, minutes: 2, seconds: 9)),
      '1:02:09',
    );
  });

  test('LrcParser parses synced timestamps, metadata, and offset properly', () {
    const sample = """
[ti:Test Track]
[ar:RYU Artist]
[al:Midnight Neon]
[offset:+500]
[00:05.00] Line one
[00:10.50] Line two
[00:18.00] Line three
""";
    final lines = LrcParser.parse(sample);
    expect(lines.length, 3);
    expect(lines.first.isSynced, true);
    expect(lines.first.text, 'Line one');
    expect(lines.first.timestamp, const Duration(milliseconds: 4500));
    expect(
      LrcParser.findActiveIndex(lines, const Duration(seconds: 12)),
      1,
    );
  });
}
