enum ConversionFamily { image, document, audioVideo, unknown }

enum OutputFormat {
  jpg,
  png,
  webp,
  pdf,
  txt,
  html,
  mp3,
  wav,
  gif,
  mp4,
  webm,
}

extension OutputFormatX on OutputFormat {
  String get extension => name;
  String get label => name.toUpperCase();

  static OutputFormat? tryParse(String raw) {
    final value = raw.toLowerCase().replaceAll('.', '');
    for (final format in OutputFormat.values) {
      if (format.name == value) return format;
    }
    if (value == 'jpeg') return OutputFormat.jpg;
    return null;
  }
}

class FormatCatalog {
  // GIFs are decoded as a still image (the first frame) for conversion.
  static const imageInputs = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tiff', 'tif'];
  static const documentInputs = ['docx', 'txt', 'md', 'html', 'htm'];
  static const avInputs = [
    'mp4', 'm4v', 'mov', 'webm', 'mkv', 'avi', 'ogv',
    'mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg',
  ];

  static const imageOutputs = [
    OutputFormat.jpg,
    OutputFormat.png,
    OutputFormat.webp,
    OutputFormat.pdf,
  ];
  static const documentOutputs = [
    OutputFormat.pdf,
    OutputFormat.txt,
    OutputFormat.html,
  ];
  static const avOutputs = [
    OutputFormat.mp4,
    OutputFormat.webm,
    OutputFormat.mp3,
    OutputFormat.wav,
    OutputFormat.gif,
  ];

  static String extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  static ConversionFamily familyFor(String nameOrExt) {
    final ext = extensionOf(nameOrExt).isEmpty
        ? nameOrExt.toLowerCase()
        : extensionOf(nameOrExt);
    if (imageInputs.contains(ext)) return ConversionFamily.image;
    if (documentInputs.contains(ext)) return ConversionFamily.document;
    if (avInputs.contains(ext)) return ConversionFamily.audioVideo;
    return ConversionFamily.unknown;
  }

  static List<OutputFormat> outputsFor(
    ConversionFamily family, {
    String? inputName,
  }) {
    switch (family) {
      case ConversionFamily.image:
        return imageOutputs;
      case ConversionFamily.document:
        return documentOutputs;
      case ConversionFamily.audioVideo:
        final input = extensionOf(inputName ?? '');
        if (const {'mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'}
            .contains(input)) {
          return const [OutputFormat.mp3, OutputFormat.wav];
        }
        if (inputName != null) {
          return const [OutputFormat.mp4, OutputFormat.webm, OutputFormat.gif];
        }
        return avOutputs;
      case ConversionFamily.unknown:
        return const [];
    }
  }

  static OutputFormat defaultOutput(ConversionFamily family, {String? inputName}) {
    final list = outputsFor(family, inputName: inputName);
    if (family == ConversionFamily.audioVideo) {
      final input = extensionOf(inputName ?? '');
      final audioInputs = {'mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'};
      return audioInputs.contains(input) ? OutputFormat.mp3 : OutputFormat.mp4;
    }
    if (family == ConversionFamily.document && list.contains(OutputFormat.txt)) {
      return OutputFormat.txt;
    }
    return list.isEmpty ? OutputFormat.pdf : list.first;
  }
}
