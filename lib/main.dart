import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:convert';

import 'orientation_dialog.dart';
import 'orientation_controller.dart';
import 'content_vault.dart';

void main() => runApp(const MyApp());

const crimson = Color(0xFFFF1744);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Privacy Screen',
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.dark,
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: crimson,
        brightness: Brightness.dark,
      ).copyWith(primary: crimson, onPrimary: Colors.white),
      scaffoldBackgroundColor: const Color(0xFF111113),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF111113),
        scrolledUnderElevation: 0,
      ),
      useMaterial3: true,
    ),
    home: const HomeScreen(),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _orientation = OrientationController();
  final _vault = ContentVault();
  final _scroll = ScrollController();
  bool _lastProtected = true;

  @override
  void initState() {
    super.initState();
    _orientation.addListener(_syncProtection);
    _orientation.start();
    _prepareContent();
  }

  Future<void> _prepareContent() async {
    final content = <String, Uint8List>{};
    void text(String id, String value) =>
        content[id] = Uint8List.fromList(utf8.encode(value));
    for (var i = 0; i < headings.length; i++) {
      text('heading-$i', headings[i]);
      text('caption-${i + 1}', 'Fig. ${i + 1} / A moment along the way');
      text('placeholder-${i + 1}', 'Placeholder image ${i + 1}');
      try {
        final bytes = await rootBundle.load('assets/images/blog-${i + 1}.jpg');
        content['image-${i + 1}'] = bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      } on FlutterError {
        // Missing user images retain their text placeholder.
      }
    }
    for (var i = 0; i < paragraphs.length; i++) {
      text('paragraph-$i', paragraphs[i]);
    }
    text('eyebrow', 'THE JOURNAL');
    text('title', 'Notes on everyday life');
    text(
      'subtitle',
      'Small observations, quiet places, and stories from the days in between.',
    );
    text('byline', 'By Alex Morgan / October 6, 2026 / 8 min read');
    await _vault.initialize(content);
    if (!mounted) return;
    await _vault.setLocked(_orientation.protected);
  }

  void _syncProtection() {
    final protected = _orientation.protected;
    if (_lastProtected == protected) return;
    _lastProtected = protected;
    if (protected) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
    _vault.setLocked(protected);
  }

  @override
  void dispose() {
    _orientation.removeListener(_syncProtection);
    _orientation.dispose();
    _vault.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static const headings = [
    'A slower start',
    'Looking a little closer',
    'Between ordinary moments',
    'Room to wander',
    'The things we keep',
    'One last thought',
  ];
  static const paragraphs = [
    'The morning arrived quietly, with light gathering at the edges of the window. Outside, the streets were already moving, but here there was still time to pause. A cup on the table, an open notebook, and a few unfinished thoughts were enough to begin the day.',
    'There is something comforting about paying attention to small things. The texture of a wall, the sound of footsteps in an empty hallway, the way a familiar place changes with the weather. Nothing remarkable has to happen for a moment to be worth remembering.',
    'Later, we took the long way home. Past the corner shop and the little garden, through streets that seemed both familiar and new. The conversation moved from one subject to another without needing to arrive anywhere, and the afternoon stretched out ahead of us.',
    'Some days leave behind a photograph. Others leave a sentence, a color, or the memory of a conversation. We collect these fragments almost without noticing, until they become a story we can return to when the details of the day have faded.',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Privacy Screen', style: TextStyle(fontSize: 18)),
      actions: [
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => OrientationDialog(controller: _orientation),
          ),
        ),
      ],
    ),
    body: _VaultScope(
      vault: _vault,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        itemCount: headings.length + 1,
        itemBuilder: (context, index) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: index == 0
                ? const _ArticleHeader()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SecureText(
                        'heading-${index - 1}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _Paragraph(
                        'paragraph-${(index - 1) % paragraphs.length}',
                      ),
                      _Paragraph('paragraph-${index % paragraphs.length}'),
                      const SizedBox(height: 8),
                      _ArticleImage(index: index),
                      const SizedBox(height: 10),
                      _SecureText(
                        'caption-$index',
                        style: const TextStyle(
                          color: Color(0xFF99999F),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _Paragraph(
                        'paragraph-${(index + 1) % paragraphs.length}',
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}

class _ArticleHeader extends StatelessWidget {
  const _ArticleHeader();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SecureText('eyebrow', style: TextStyle(color: crimson, fontSize: 12)),
      SizedBox(height: 18),
      _SecureText(
        'title',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
      SizedBox(height: 18),
      _SecureText(
        'subtitle',
        style: TextStyle(fontSize: 18, color: Color(0xFFB5B5BD), height: 1.6),
      ),
      SizedBox(height: 22),
      _SecureText(
        'byline',
        style: TextStyle(fontSize: 12, color: Color(0xFF99999F), height: 1.6),
      ),
      SizedBox(height: 28),
      Divider(color: Color(0xFF303034)),
      SizedBox(height: 32),
    ],
  );
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: _SecureText(
      text,
      style: const TextStyle(
        fontSize: 17,
        height: 1.85,
        color: Color(0xFFD0D0D5),
      ),
    ),
  );
}

class _ArticleImage extends StatelessWidget {
  const _ArticleImage({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final vault = _VaultScope.of(context);
    final image = vault.image('image-$index');
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: vault.locked
          ? CustomPaint(
              painter: _EncryptedImagePainter(
                vault.encryptedImage('image-$index') ?? const [31, 97, 143],
              ),
              child: const Center(
                child: Icon(Icons.lock_outline, color: Colors.white),
              ),
            )
          : image != null
          ? Image.memory(image, fit: BoxFit.cover)
          : ColoredBox(
              color: const Color(0xFF222225),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image_outlined, color: crimson, size: 36),
                    const SizedBox(height: 12),
                    _SecureText(
                      'placeholder-$index',
                      style: const TextStyle(color: Color(0xFF99999F)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _VaultScope extends InheritedNotifier<ContentVault> {
  const _VaultScope({required ContentVault vault, required super.child})
    : super(notifier: vault);
  static ContentVault of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_VaultScope>()!.notifier!;
}

class _SecureText extends StatelessWidget {
  const _SecureText(this.id, {this.style});
  final String id;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final vault = _VaultScope.of(context);
    if (!vault.locked) return Text(vault.text(id) ?? '', style: style);
    final ciphertext = vault.ciphertext(id);
    return Semantics(
      label: 'Encrypted text',
      excludeSemantics: true,
      child: Text(
        ciphertext ?? vault.error ?? 'Protecting content...',
        maxLines: 4,
        overflow: TextOverflow.clip,
        style: (style ?? const TextStyle()).copyWith(
          color: const Color(0xFF99999F),
        ),
      ),
    );
  }
}

class _EncryptedImagePainter extends CustomPainter {
  const _EncryptedImagePainter(this.bytes);
  final List<int> bytes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const columns = 48;
    const rows = 30;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        final i = (y * columns + x) * 3;
        paint.color = Color.fromARGB(
          255,
          bytes[i % bytes.length],
          bytes[(i + 1) % bytes.length],
          bytes[(i + 2) % bytes.length],
        );
        canvas.drawRect(
          Rect.fromLTWH(
            x * size.width / columns,
            y * size.height / rows,
            size.width / columns + 1,
            size.height / rows + 1,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EncryptedImagePainter oldDelegate) =>
      oldDelegate.bytes != bytes;
}
