// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import '../back_end/code_writer.dart';
import 'piece.dart';

/// A piece for the `for (...)` part of a for statement or element.
final class ForPiece extends Piece {
    /// The `for` keyword.
    final Piece _forKeyword;

    /// The part inside `( ... )`, including the parentheses themselves, at the
    /// header of a for statement.
    final Piece _parts;

    /// Whether the contents of the parentheses in the `for (...)` should be
    /// expression indented or not.
    ///
    /// This is usually not necessary because the contents will either be a
    /// [ListPiece] which adds its own block indentation, or an [AssignPiece]
    /// which indents as necessary. But in the rare case the for-parts is a
    /// variable or pattern variable declaration with metadata that splits, we
    /// need to ensure that the metadata is indented, as in:
    ///
    ///     for (@LongAnnotation
    ///         @AnotherAnnotation
    ///         var element in list) { ... }
    final bool _indent;

    ForPiece(
        this._forKeyword,
        this._parts, {
        required bool indent,
    }): _indent = indent;

    @override
    void format(CodeWriter writer, State state) {
        writer.format(_forKeyword);
        writer.space();
        if (_indent) writer.pushCollapsibleIndent();
        writer.format(_parts);
        if (_indent) writer.popIndent();
    }

    @override
    void forEachChild(void Function(Piece piece) callback) {
        callback(_forKeyword);
        callback(_parts);
    }
}

/// A piece for the `<variable> in <expression>` part of a for-in loop.
///
/// Can be formatted two ways:
///
/// [State.unsplit] No split at all:
///
///     for (var x in y) ...
///
/// This state also allows splitting the sequence expression if it's block
/// shaped:
///
///     for (var i in [
///       element1,
///       element2,
///       element3,
///     ];
///
/// [State.split] Split at the `in` operator and allow expression splitting on
/// either side. Allows:
///
///     for (var (longVariable &&
///             anotherVariable)
///         in longOperand +
///             anotherOperand) {
///       ...
///     }
abstract base class ForInPiece extends Piece {
    /// The variable or pattern initialized with each loop iteration.
    final Piece _variable;

    /// The `in` keyword followed by the sequence expression.
    final Piece _sequence;

    factory ForInPiece(
        Piece variable,
        Piece sequence, {
        bool canBlockSplitSequence = false,
        required bool version37,
    }) {
        if (version37) {
            return _ForInPieceV37(variable, sequence, canBlockSplitSequence: canBlockSplitSequence);
        } else {
            return _ForInPiece(variable, sequence);
        }
    }

    ForInPiece._(
        this._variable,
        this._sequence,
    );

    @override
    List<State> get additionalStates => const [State.split];

    @override
    void format(CodeWriter writer, State state) {
        // When splitting at `in`, both operands may split or not and will be
        // indented if they do.
        if (state == State.split) writer.pushIndent(Indent.expression);

        writer.format(_variable);
        writer.splitIf(state == State.split);
        writer.format(_sequence);

        if (state == State.split) writer.popIndent();
    }

    @override
    void forEachChild(void Function(Piece piece) callback) {
        callback(_variable);
        callback(_sequence);
    }
}

/// A [ForInPiece] subclass for 3.8 and later style.
final class _ForInPiece extends ForInPiece {
    _ForInPiece(
        super._variable,
        super._sequence,
    ): super._();

    @override
    Set<Shape> allowedChildShapes(State state, Piece child) => switch (state) {
        // Always allow block-splitting the sequence if it supports it.
        State.unsplit when child == _sequence => const {Shape.inline, Shape.block},
        State.unsplit => Shape.onlyInline,
        _ => Shape.all,
    };
}

/// A [ForInPiece] subclass for 3.7 style.
final class _ForInPieceV37 extends ForInPiece {
    /// If `true` then the sequence expression supports being block-formatted,
    /// like:
    ///
    ///     for (var e in [
    ///       element1,
    ///       element2,
    ///     ]) {
    ///       // ...
    ///     }
    final bool _canBlockSplitSequence;

    _ForInPieceV37(
        super._variable,
        super._sequence, {
        bool canBlockSplitSequence = false,
    }): _canBlockSplitSequence = canBlockSplitSequence,
        super._();

    @override
    Set<Shape> allowedChildShapes(State state, Piece child) {
        if (state == State.split) return Shape.all;

        // Always allow block-splitting the sequence if it supports it.
        return Shape.anyIf(child == _sequence && _canBlockSplitSequence);
    }
}
