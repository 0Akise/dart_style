// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A mixin for marking classes.
mixin Markable {
    bool _isMarked = false;

    bool mark() {
        if (_isMarked) return false;
        _isMarked = true;
        return true;
    }

    bool get isMarked => _isMarked;

    void unmark() {
        _isMarked = false;
    }
}
