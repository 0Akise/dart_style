// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Internal debugging utilities.
library;

import 'dart:math' as math;

import 'dart_formatter.dart';
import 'piece/piece.dart';
import 'short/chunk.dart';
import 'short/line_splitting/rule_set.dart';

/// Set this to `true` to turn on diagnostic output while building chunks.
bool traceChunkBuilder = false;

/// Set this to `true` to turn on diagnostic output while writing lines.
bool traceLineWriter = false;

/// Set this to `true` to turn on diagnostic output while line splitting.
bool traceSplitter = false;

/// Set this to `true` to turn on diagnostic output while building pieces.
bool tracePieceBuilder = false;

/// Set this to `true` to turn on diagnostic output while merging indentation.
bool traceIndent = false;

/// Set this to `true` to turn on diagnostic output while solving pieces.
bool traceSolver = false;

/// Set this to `true` to turn on diagnostic output when the solver enqueues a
/// potential solution.
bool traceSolverEnqueing = false;

/// Set this to `true` to turn on diagnostic output when the solver dequeues a
/// potential solution.
bool traceSolverDequeing = false;

/// Set this to `true` to show the formatted code for a given solution when the
/// solver it printing diagnostic output.
bool traceSolverShowCode = false;

bool useAnsiColors = false;

const unicodeSection = '\u00a7';
const unicodeMidDot = '\u00b7';

/// The whitespace prefixing each line of output.
String _indent = '';

void indent() {
    _indent = '  $_indent';
}

void unindent() {
    _indent = _indent.substring(2);
}

/// Constants for ANSI color escape codes.
final _gray = _color('\u001b[1;30m');
final _green = _color('\u001b[32m');
final _red = _color('\u001b[31m');
final _none = _color('\u001b[0m');
final _bold = _color('\u001b[1m');

/// Prints [message] to stdout with each line correctly indented.
void log([Object? message]) {
    if (message == null) {
        print('');
        return;
    }

    print(_indent + message.toString().replaceAll('\n', '\n$_indent'));
}

/// Wraps [message] in gray ANSI escape codes if enabled.
String gray(Object message) => '$_gray$message$_none';

/// Wraps [message] in green ANSI escape codes if enabled.
String green(Object message) => '$_green$message$_none';

/// Wraps [message] in green ANSI escape codes if enabled.
String red(Object message) => '$_red$message$_none';

/// Wraps [message] in bold ANSI escape codes if enabled.
String bold(Object message) => '$_bold$message$_none';

/// Prints [chunks] to stdout, one chunk per line, with detailed information
/// about each chunk.
void dumpChunks(int start, List<Chunk> chunks) {
    if (chunks.skip(start).isEmpty) return;

    // Show the spans as vertical bands over their range (unless there are too
    // many).
    var spanSet = <Span>{};
    void addSpans(List<Chunk> chunks) {
        for (var chunk in chunks) {
            spanSet.addAll(chunk.spans);

            if (chunk is BlockChunk) addSpans(chunk.children);
        }
    }

    addSpans(chunks);

    var rows = <List<String>>[];

    void addChunk(List<Chunk> chunks, String prefix, int index) {
        var chunk = chunks[index];

        if (chunk is BlockChunk) {
            for (var j = 0; j < chunk.children.length; j++) {
                addChunk(chunk.children, '$prefix$index.', j);
            }
        }

        var row = <String>[];
        row.add('$prefix$index:');

        void writeIf(bool predicate, String Function() callback) {
            if (predicate) {
                row.add(callback());
            } else {
                row.add('');
            }
        }

        var rule = chunk.rule;
        writeIf(rule.cost != 0, () => '\$${rule.cost}');

        var ruleString = rule.toString();
        if (rule.isHardened) ruleString += '!';
        row.add(ruleString);

        var rules = chunks.map((chunk) => chunk.rule).toSet();
        var constrainedRules = rule.constrainedRules.toSet().intersection(rules);
        writeIf(constrainedRules.isNotEmpty, () => "-> ${constrainedRules.join(" ")}");

        var properties = [
            if (chunk.flushLeft) 'fl',
            if (chunk.isDouble) '2x',
            if (chunk.spaceWhenUnsplit) 'sp',
            if (chunk.canDivide) 'dv',
        ].join(' ');
        row.add(properties);

        writeIf(chunk.indent != 0, () => 'indent ${chunk.indent}');
        writeIf(chunk.nesting.indent != 0, () => 'nest ${chunk.nesting}');

        var spans = spanSet.toList();
        if (spans.length <= 20) {
            var spanBars = '';
            for (var span in spans) {
                if (chunk.spans.contains(span)) {
                    if (index == chunks.length - 1 || !chunks[index + 1].spans.contains(span)) {
                        // This is the last chunk with the span.
                        spanBars += '╙';
                    } else {
                        spanBars += '║';
                    }
                } else {
                    // If the next chunk has this span, then show it bridging this chunk
                    // and the next because a split between them breaks the span.
                    if (index < chunks.length - 1 && chunks[index + 1].spans.contains(span)) {
                        if (span.cost == 1) {
                            spanBars += '╓';
                        } else {
                            spanBars += span.cost.toString();
                        }
                    }
                }
            }
            row.add(spanBars);
        }

        row.add(chunk.spans.map((span) => span.id).join(' '));

        if (chunk.text.length > 70) {
            row.add(chunk.text.substring(0, 70));
        } else {
            row.add(chunk.text);
        }

        rows.add(row);
    }

    for (var i = start; i < chunks.length; i++) {
        addChunk(chunks, '', i);
    }

    var rowWidths = List.filled(rows.first.length, 0);
    for (var row in rows) {
        for (var i = 0; i < row.length; i++) {
            rowWidths[i] = math.max(rowWidths[i], row[i].length);
        }
    }

    var buffer = StringBuffer();
    for (var row in rows) {
        for (var i = 0; i < row.length; i++) {
            if (rowWidths[i] == 0) continue;

            var cell = row[i].padRight(rowWidths[i]);

            if (i != row.length - 1) cell = gray(cell);

            buffer.write(cell);
            buffer.write('  ');
        }

        buffer.writeln();
    }

    print(buffer.toString());
}

/// Shows all of the constraints between the rules used by [chunks].
void dumpConstraints(List<Chunk> chunks) {
    var rules = chunks.map((chunk) => chunk.rule).toSet();

    for (var rule in rules) {
        var constrainedValues = <String>[];
        for (var value = 0; value < rule.numValues; value++) {
            var constraints = <String>[];
            for (var other in rules) {
                if (rule == other) continue;

                var constraint = rule.constrain(value, other);
                if (constraint != null) {
                    constraints.add('$other->$constraint');
                }
            }

            if (constraints.isNotEmpty) {
                constrainedValues.add("$value:(${constraints.join(' ')})");
            }
        }

        log("$rule ${constrainedValues.join(' ')}");
    }
}

/// Convert the line to a [String] representation.
///
/// It will determine how best to split it into multiple lines of output and
/// return a single string that may contain one or more newline characters.
void dumpLines(List<Chunk> chunks, SplitSet splits) {
    var buffer = StringBuffer();

    void writeChunksUnsplit(List<Chunk> chunks) {
        for (var chunk in chunks) {
            if (chunk.spaceWhenUnsplit) buffer.write(' ');

            // Recurse into the block.
            if (chunk is BlockChunk) writeChunksUnsplit(chunk.children);

            buffer.write(chunk.text);
        }
    }

    for (var i = 0; i < chunks.length; i++) {
        var chunk = chunks[i];

        if (splits.shouldSplitAt(i)) {
            for (var j = 0; j < (chunk.isDouble ? 2 : 1); j++) {
                buffer.writeln();
                buffer.write(gray('| ' * (splits.getColumn(i) ~/ 2)));
            }
        } else if (chunk.spaceWhenUnsplit) {
            buffer.write(' ');
        }

        if (chunk is BlockChunk && !splits.shouldSplitAt(i)) {
            writeChunksUnsplit(chunk.children);
        }

        buffer.write(chunk.text);
    }

    log(buffer);
}

/// Build a string representation of the [piece] tree.
String pieceTree(Piece piece) {
    var buffer = StringBuffer();
    _PieceDebugTree(piece).write(buffer, 0);
    return buffer.toString();
}

/// A stringified representation of a tree of pieces for debug output.
final class _PieceDebugTree {
    final String label;
    final List<_PieceDebugTree> children = [];

    _PieceDebugTree(
        Piece piece,
    ): label = piece.toString() {
        piece.forEachChild((child) {
            children.add(_PieceDebugTree(child));
        });
    }

    /// The approximate number of characters of output needed to print this tree
    /// on a single line.
    ///
    /// Used to determine when to show a tree's children inline or split. Note
    /// that this is O(n^2), but we don't really care since it's only used for
    /// debug output.
    int get width {
        var result = label.length;
        for (var child in children) {
            result += child.width;
        }
        return result;
    }

    void write(StringBuffer buffer, int indent) {
        buffer.write(label);
        if (children.isEmpty) return;

        buffer.write('(');

        // Split the tree if it is too long.
        var isSplit = indent * 2 + width > DartFormatter.defaultPageWidth;
        if (isSplit) {
            indent++;
            buffer.writeln();
            buffer.write('  ' * indent);
        }

        var first = true;
        for (var child in children) {
            if (!first) {
                if (isSplit) {
                    buffer.writeln();
                    buffer.write('  ' * indent);
                } else {
                    buffer.write(' ');
                }
            }

            child.write(buffer, indent);

            first = false;
        }

        if (isSplit) {
            indent--;
            buffer.writeln();
            buffer.write('  ' * indent);
        }

        buffer.write(')');
    }
}

String _color(String ansiEscape) => useAnsiColors ? ansiEscape : '';
