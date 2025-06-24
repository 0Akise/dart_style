// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

import '../dart_formatter.dart';
import '../source_code.dart';
import 'output.dart';
import 'show.dart';
import 'summary.dart';

// Note: The following line of code is modified by tool/grind.dart.
const dartStyleVersion = '3.1.0';

/// Global options parsed from the command line that affect how the formatter
/// produces and uses its outputs.
final class FormatterOptions {
    final Version? languageVersion;
    final int indent;
    final int indentSize;
    final int? pageWidth;
    final TrailingCommas? trailingCommas;
    final bool followLinks;
    final Show show;
    final Output output;
    final Summary summary;
    final bool setExitIfChanged;
    final List<String> experimentFlags;

    FormatterOptions({
        this.languageVersion,
        this.indent = 0,
        this.indentSize = 4,
        this.pageWidth,
        this.trailingCommas,
        required this.followLinks,
        required this.show,
        required this.output,
        required this.summary,
        required this.setExitIfChanged,
        required this.experimentFlags,
    });

    /// Called when [file] is about to be formatted.
    ///
    /// If stdin is being formatted, then [file] is `null`.
    void beforeFile(File? file, String label) {
        summary.beforeFile(file, label);
    }

    /// Describe the processed file at [path] with formatted [result]s.
    ///
    /// If the contents of the file are the same as the formatted output,
    /// [changed] will be false.
    ///
    /// If stdin is being formatted, then [file] is `null`.
    void afterFile(
        File? file,
        String displayPath,
        SourceCode result, {
        required bool changed,
    }) {
        summary.afterFile(this, file, displayPath, result, changed: changed);

        // Save the results to disc.
        var overwritten = false;
        if (changed) {
            overwritten = output.writeFile(file, displayPath, result);
        }

        // Show the user.
        if (show.file(
            displayPath,
            changed: changed,
            overwritten: overwritten,
        )) {
            output.showFile(displayPath, result);
        }

        // Set the exit code.
        if (setExitIfChanged && changed) exitCode = 1;
    }
}
