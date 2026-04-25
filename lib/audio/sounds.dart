List<String> soundTypeToFilename(SfxType type) => switch (type) {
  SfxType.wssh => const [
    'wssh1.mp3',
    'wssh2.mp3',
    'dsht1.mp3',
    'ws1.mp3',
    'spsh1.mp3',
    'hh1.mp3',
    'hh2.mp3',
    'kss1.mp3',
  ],
  SfxType.buttonTap => const ['k1.mp3', 'k2.mp3', 'p1.mp3', 'p2.mp3'],
};

/// Per-type volume so quieter accents don't drown out gameplay.
double soundTypeToVolume(SfxType type) => switch (type) {
  SfxType.wssh => 0.2,
  SfxType.buttonTap => 1.0,
};

enum SfxType { wssh, buttonTap }
