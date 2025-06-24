class GlobalIndentConfig {
    static int _blockSize = 4;
    static int get blockSize => _blockSize;
    static void setBlockSize(int size) => _blockSize = size;
    static int get block => _blockSize;
    static int get cascade => _blockSize;
    static int get expression => _blockSize * 2;
    static int get assignment => _blockSize * 2;
    static int get controlFlowClause => _blockSize * 2;
    static int get infix => _blockSize * 2;
    static int get initializer => _blockSize;
    static int get initializerWithOptionalParameter => _blockSize + 1;
    static int get grouping => 0;
    static int get none => 0;
}
