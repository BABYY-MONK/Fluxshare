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
  // Audio/video formats are hidden until the ffmpeg.wasm bundle is shipped.
  static const avInputs = <String>[];

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
  static const avOutputs = <OutputFormat>[];

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

  static List<OutputFormat> outputsFor(ConversionFamily family) {
    switch (family) {
      case ConversionFamily.image:
        return imageOutputs;
      case ConversionFamily.document:
        return documentOutputs;
      case ConversionFamily.audioVideo:
        return avOutputs;
      case ConversionFamily.unknown:
        return const [];
    }
  }

  static OutputFormat defaultOutput(ConversionFamily family) {
    final list = outputsFor(family);
    if (family == ConversionFamily.document && list.contains(OutputFormat.txt)) {
      return OutputFormat.txt;
    }
    return list.isEmpty ? OutputFormat.pdf : list.first;
  }
}
