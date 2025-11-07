import 'package:flutter/material.dart';

class FeedbackScreen extends StatefulWidget {
  final bool isDark;
  const FeedbackScreen({Key? key, this.isDark = false}) : super(key: key);

  @override
  _FeedbackScreenState createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  // Warna kustom pengganti biru
  final Color customColor = const Color(0xFFAEEE00);

  // State untuk menyimpan pilihan pengguna
  int _rating = 0; // 0 = belum ada rating
  int? _selectedChipIndex; // null = belum ada pilihan
  final _textController = TextEditingController();
  bool _wantsToParticipate = false;

  final List<String> _feedbackOptions = [
    'Pertanyaan atau permintaan fitur aplikasi',
    'Keuntungan pelanggan premium',
    'Laporkan bug',
    'Komentar umum',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Tentukan warna teks chip berdasarkan tema
    final chipTextColor = widget.isDark ? Colors.white : Colors.black;
    // Tentukan warna teks untuk tombol utama (agar kontras dengan customColor)
    final buttonTextColor = Colors.black;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Kirim Masukan',
          style: TextStyle(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bagaimana pengalaman Anda?',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Jika Anda memiliki pertanyaan atau butuh bantuan menyelesaikan masalah, Anda dapat menemukan jawaban di FAQ kami, atau hubungi kami.',
                style: theme.textTheme.bodyMedium,
              ),
              const Divider(height: 32),

              // --- Bagian Rating Bintang ---
              Text(
                'Beri peringkat pengalaman Anda dengan aplikasi Insider.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Wajib (tanggapan Anda tidak akan dibagikan secara publik)',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      // Gunakan warna kustom saat terisi
                      color: index < _rating ? customColor : Colors.grey,
                      size: 36,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 24),

              // --- Bagian Pilihan Spesifik ---
              Text(
                'Punya masukan atau komentar spesifik?',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: List.generate(_feedbackOptions.length, (index) {
                  final isSelected = _selectedChipIndex == index;
                  return ChoiceChip(
                    label: Text(_feedbackOptions[index]),
                    selected: isSelected,
                    // Style saat terpilih
                    selectedColor: customColor.withOpacity(0.2),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: isSelected ? customColor : Colors.grey.shade400,
                      ),
                    ),
                    // Style label (agar kontras)
                    labelStyle: TextStyle(
                      color: isSelected ? chipTextColor : chipTextColor.withOpacity(0.7),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedChipIndex = selected ? index : null;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 24),

              // --- Bagian Teks Area ---
              Text(
                'Ceritakan lebih lanjut...',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _textController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      'Beri tahu kami apa yang Anda suka tentang aplikasi, atau apa yang bisa kami lakukan lebih baik.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5), // Radius 5
                  ),
                  // Warna border akan menyesuaikan theme
                ),
              ),
              const SizedBox(height: 24),

              // --- Bagian Checkbox ---
              Row(
                children: [
                  Checkbox(
                    value: _wantsToParticipate,
                    // Gunakan warna kustom
                    activeColor: customColor,
                    onChanged: (value) {
                      setState(() {
                        _wantsToParticipate = value ?? false;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Saya bersedia berpartisipasi dalam survei dan sesi masukan di masa mendatang.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Tombol Kirim ---
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  // Warna tombol utama
                  backgroundColor: customColor,
                  // Warna teks tombol
                  foregroundColor: buttonTextColor,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5), // Radius 5
                  ),
                ),
                onPressed: () {
                  // Aksi saat tombol diklik
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Belum diimplementasikan'),
                    ),
                  );
                },
                child: const Text(
                  'Kirim',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}