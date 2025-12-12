class MifareBlock {
  final int sector;
  final int block;
  final int absBlock;
  final String hex;
  final String text;
  final bool isTrailer;

  MifareBlock({
    required this.sector,
    required this.block,
    required this.absBlock,
    required this.hex,
    required this.text,
    required this.isTrailer,
  });

  factory MifareBlock.fromMap(Map<String, dynamic> map) {
    return MifareBlock(
      sector: map['sector'] ?? 0,
      block: map['block'] ?? 0,
      absBlock: map['absBlock'] ?? 0,
      hex: map['hex'] ?? '',
      text: map['text'] ?? '',
      isTrailer: map['isTrailer'] ?? false,
    );
  }
}

class MifareSector {
  final int number;
  final List<MifareBlock> blocks;
  final bool authenticated;

  MifareSector({
    required this.number,
    required this.blocks,
    required this.authenticated,
  });
}