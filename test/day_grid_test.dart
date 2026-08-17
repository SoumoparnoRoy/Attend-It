import 'package:flutter_test/flutter_test.dart';

import 'package:attend_it/domain/day_grid.dart';

/// 9:00–17:00 on 50-minute blocks: nine blocks with 30 minutes to spare.
const DayGrid _grid = DayGrid(
  dayStartMinutes: 9 * 60,
  dayEndMinutes: 17 * 60,
  blockMinutes: 50,
);

void main() {
  group('shape of the day', () {
    test('counts only whole blocks and reports the remainder', () {
      expect(_grid.blockCount, 9);
      expect(_grid.leftoverMinutes, 30);
      expect(_grid.isConfigured, isTrue);
    });

    test('is unconfigured without a block length', () {
      const DayGrid none = DayGrid(
        dayStartMinutes: 9 * 60,
        dayEndMinutes: 17 * 60,
        blockMinutes: 0,
      );
      expect(none.isConfigured, isFalse);
      expect(none.blockCount, 0);
      expect(DayGrid.none.isConfigured, isFalse);
    });

    test('is unconfigured when the day ends before it starts', () {
      const DayGrid backwards = DayGrid(
        dayStartMinutes: 17 * 60,
        dayEndMinutes: 9 * 60,
        blockMinutes: 50,
      );
      expect(backwards.isConfigured, isFalse);
      expect(backwards.leftoverMinutes, 0);
    });

    test('blocks run back to back from the start of the day', () {
      expect(_grid.startOf(0), 9 * 60);
      expect(_grid.endOf(0), 9 * 60 + 50);
      expect(_grid.startOf(1), _grid.endOf(0));
      expect(_grid.startOf(8), 9 * 60 + 8 * 50);
    });
  });

  group('a class is a whole number of blocks', () {
    test('a lecture is one and a double lab is two', () {
      expect(_grid.blocksFor(50), 1);
      expect(_grid.blocksFor(100), 2);
    });

    test('a hand-typed near miss still reads as the block it meant', () {
      expect(_grid.blocksFor(95), 2);
      expect(_grid.blocksFor(105), 2);
    });

    test('never less than one block, whatever the length', () {
      expect(_grid.blocksFor(0), 1);
      expect(_grid.blocksFor(5), 1);
    });

    test('snapping rounds to the nearest block boundary', () {
      expect(_grid.snapDuration(95), 100);
      expect(_grid.snapDuration(50), 50);
    });

    test('an unconfigured grid leaves lengths alone', () {
      expect(DayGrid.none.snapDuration(95), 95);
      expect(DayGrid.none.blocksFor(95), 1);
    });

    test('only exact multiples count as whole blocks', () {
      expect(_grid.isWholeBlocks(100), isTrue);
      expect(_grid.isWholeBlocks(95), isFalse);
      expect(_grid.isWholeBlocks(0), isFalse);
      expect(DayGrid.none.isWholeBlocks(50), isFalse);
    });
  });

  group('placing a class on the grid', () {
    test('a start time lands in the block that contains it', () {
      expect(_grid.indexOf(9 * 60), 0);
      expect(_grid.indexOf(9 * 60 + 49), 0);
      expect(_grid.indexOf(9 * 60 + 50), 1);
    });

    test('a class outside the teaching day has no block', () {
      expect(_grid.indexOf(8 * 60), isNull);
      expect(_grid.indexOf(17 * 60), isNull);
    });

    test('alignment separates grid classes from ones typed by hand', () {
      expect(_grid.isAligned(9 * 60 + 50), isTrue);
      expect(_grid.isAligned(9 * 60 + 30), isFalse);
      expect(_grid.isAligned(8 * 60), isFalse);
    });
  });
}
