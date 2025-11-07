import 'package:flutter/material.dart';
import '../models/article.dart'; // Sesuaikan path ke model Article
import '../services/bookmark_service.dart'; // Sesuaikan path ke BookmarkService

// Widget Stateful untuk modal pemilihan/pembuatan grup bookmark
class BookmarkGroupModal extends StatefulWidget {
  final Article article; // Artikel yang akan disimpan
  final BookmarkService bookmarkService; // Service untuk logika bookmark

  const BookmarkGroupModal({
    Key? key,
    required this.article,
    required this.bookmarkService,
  }) : super(key: key);

  @override
  _BookmarkGroupModalState createState() => _BookmarkGroupModalState();
}

class _BookmarkGroupModalState extends State<BookmarkGroupModal> {
  // Controller untuk field input nama grup baru
  final _newGroupController = TextEditingController();
  // List untuk menyimpan nama grup yang sudah ada
  List<String> _groups = [];
  // Status loading saat mengambil daftar grup
  bool _isLoading = true;
  // Menyimpan nama grup yang dipilih dari RadioListTile
  String? _selectedGroup;

  @override
  void initState() {
    super.initState();
    // Muat daftar grup saat modal pertama kali dibuka
    _loadGroups();
  }

  // Fungsi asinkron untuk memuat daftar grup dari BookmarkService
  Future<void> _loadGroups() async {
    // Set status loading menjadi true
    if (mounted) setState(() => _isLoading = true);
    try {
      // Panggil service untuk mendapatkan daftar grup
      final groups = await widget.bookmarkService.getGroups();
      // Jika widget masih ada di tree
      if (mounted) {
        setState(() {
          // Urutkan grup berdasarkan abjad (opsional)
          groups.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _groups = groups; // Simpan daftar grup ke state
          _isLoading = false; // Set status loading menjadi false
        });
      }
    } catch (e) {
      // Jika terjadi error saat memuat grup
      if (mounted) {
         setState(() => _isLoading = false); // Set loading false
         // Tampilkan pesan error menggunakan SnackBar
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Gagal memuat grup: $e'), backgroundColor: Colors.red),
         );
      }
    }
  }

  // Fungsi asinkron untuk menyimpan artikel ke grup yang dipilih/baru
  Future<void> _saveToGroup(String groupName) async {
     // Bersihkan nama grup dari spasi
     final trimmedName = groupName.trim();
     // Validasi nama grup tidak boleh kosong
     if (trimmedName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Nama koleksi tidak boleh kosong'), backgroundColor: Colors.orange),
        );
        return; // Hentikan proses jika nama kosong
     }

     // Tampilkan dialog loading sederhana saat proses penyimpanan
     showDialog(
       context: context,
       builder: (context) => const Center(child: CircularProgressIndicator()),
       barrierDismissible: false // Jangan tutup dialog loading saat diklik di luar
     );

     try {
       // Panggil service untuk menambahkan bookmark
       await widget.bookmarkService.addBookmark(widget.article, trimmedName);
       // Tutup dialog loading jika berhasil
       if (mounted) Navigator.pop(context);
       // Tutup modal bottom sheet dan kembalikan nama grup yang berhasil disimpan
       if (mounted) Navigator.pop(context, trimmedName);
     } catch (e) {
        // Tutup dialog loading jika terjadi error
        if (mounted) Navigator.pop(context);
        // Tampilkan pesan error (jangan tutup modal agar user tahu ada masalah)
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
           );
        }
     }
  }

  @override
  void dispose() {
    // Selalu dispose controller saat widget tidak lagi digunakan
    _newGroupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cek tema gelap/terang
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Padding untuk modal, termasuk viewInsets agar tidak tertutup keyboard
    return Padding(
      padding: EdgeInsets.only(
        // Padding bawah = viewInsets (keyboard) + padding tambahan
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 20, // Padding atas modal
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Tinggi modal secukupnya
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Header Modal: Judul dan Tombol Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Simpan ke Koleksi',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              // Tombol 'X' untuk menutup modal
              IconButton(
                 icon: const Icon(Icons.close_rounded),
                 onPressed: () => Navigator.pop(context), // Tutup modal tanpa hasil
                 tooltip: 'Batal',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tampilkan loading indicator atau konten modal
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
          else ...[ // '...' (spread operator) untuk memasukkan beberapa widget
            // --- Bagian Daftar Grup yang Sudah Ada ---
            // Tampilkan hanya jika list _groups tidak kosong
            if (_groups.isNotEmpty) ...[
              Text('Pilih Koleksi:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              // Gunakan ConstrainedBox untuk membatasi tinggi ListView
              ConstrainedBox(
                 constraints: BoxConstraints(
                   // Tinggi maksimal list adalah 25% dari tinggi layar
                   maxHeight: MediaQuery.of(context).size.height * 0.25,
                 ),
                 // Gunakan ListView.builder untuk menampilkan grup
                 child: ListView.builder(
                   shrinkWrap: true, // Agar ListView menyesuaikan tingginya
                   itemCount: _groups.length,
                   itemBuilder: (context, index) {
                     final group = _groups[index];
                     // Gunakan RadioListTile untuk memungkinkan pemilihan satu grup
                     return RadioListTile<String>(
                       title: Text(group),
                       value: group, // Nilai radio button adalah nama grup
                       groupValue: _selectedGroup, // Nilai yang sedang terpilih
                       onChanged: (value) {
                         // Callback saat radio button dipilih
                         setState(() => _selectedGroup = value); // Update state pilihan
                         // Langsung simpan ke grup yang dipilih
                         if (value != null) {
                            _saveToGroup(value);
                         }
                       },
                       activeColor: Colors.yellow[700], // Warna aksen saat terpilih
                       contentPadding: EdgeInsets.zero, // Hapus padding default
                       visualDensity: VisualDensity.compact, // Buat lebih rapat
                     );
                   },
                 ),
              ),
              const SizedBox(height: 24), // Jarak sebelum input baru
            ],

            // --- Bagian Input untuk Grup Baru ---
             Text(
                 // Sesuaikan label berdasarkan apakah sudah ada grup atau belum
                 _groups.isEmpty ? 'Buat Koleksi Baru:' : 'Atau Buat Koleksi Baru:',
                 style: Theme.of(context).textTheme.titleMedium
             ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Sejajarkan vertikal
              children: [
                // TextField untuk memasukkan nama grup baru
                Expanded(
                  child: TextField(
                    controller: _newGroupController,
                    decoration: InputDecoration(
                      hintText: 'Nama koleksi baru...',
                      filled: true,
                      fillColor: isDark ? Colors.grey[850] : Colors.grey[200], // Warna field
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none, // Tanpa border
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      isDense: true, // Buat field lebih compact
                    ),
                    textCapitalization: TextCapitalization.words, // Kapitalisasi otomatis
                    // Saat mulai mengetik, batalkan pilihan radio (jika ada)
                    onChanged: (value) {
                      if (_selectedGroup != null && value.isNotEmpty) {
                         if (mounted) setState(() => _selectedGroup = null);
                      }
                    },
                    // Simpan saat menekan 'done'/'enter' di keyboard
                    onSubmitted: (value) => _saveToGroup(value),
                  ),
                ),
                const SizedBox(width: 10), // Jarak antara field dan tombol
                // Tombol 'Simpan' untuk membuat grup baru
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: const Text('Simpan'),
                  onPressed: () {
                     final newGroupName = _newGroupController.text;
                     _saveToGroup(newGroupName); // Panggil fungsi simpan
                  },
                   style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow[700], // Warna tombol
                      foregroundColor: Colors.black, // Warna teks tombol
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Tombol rounded
                      elevation: 1, // Sedikit shadow
                   ),
                ),
              ],
            ),
          ],
          // Beri jarak aman di bagian paling bawah modal
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

