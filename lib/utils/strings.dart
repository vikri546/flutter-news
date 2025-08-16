class AppStrings {
  final String languageCode;
  AppStrings(this.languageCode);

  bool get isEn => languageCode == 'en';

  String get appTitle => isEn ? "d'talk app" : "d'talk aplikasi";
  String get home => isEn ? 'Home' : 'Beranda';
  String get bookmark => isEn ? 'Bookmark' : 'Bookmark';
  String get about => isEn ? 'About' : 'Tentang';
  String get bookmarksTitle => isEn ? 'Bookmarks' : 'Bookmark';
  String get noBookmarksYet => isEn ? 'No bookmarks yet' : 'Belum ada bookmark';
  String get saveUpTo5 => isEn
      ? 'You can save up to 5 bookmarks'
      : 'Anda dapat menyimpan hingga 5 bookmark';
  String get logout => isEn ? 'Logout' : 'Keluar';
  String get logoutConfirmTitle => isEn ? 'Logout' : 'Keluar';
  String get logoutConfirmMessage => isEn
      ? 'Are you sure you want to logout?'
      : 'Apakah Anda yakin ingin keluar?';
  String get cancel => isEn ? 'Cancel' : 'Batal';
  String get searchEmptyCategory => isEn
      ? 'No articles found in this category'
      : 'Tidak ada artikel dalam kategori ini';
  String get notificationsUpcoming =>
      isEn ? 'This feature upcoming' : 'Fitur ini segera hadir';
  String get max5Bookmarks => isEn
      ? 'Maximum 5 bookmarks. Delete one to add a new one.'
      : 'Maksimal 5 bookmark. Hapus satu untuk menambah yang baru.';
  String get welcome => isEn ? 'Welcome' : 'Selamat datang';
  String get language => isEn ? 'Language' : 'Bahasa';
  String get english => 'EN';
  String get indonesian => 'ID';
}
