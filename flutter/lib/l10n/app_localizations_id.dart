// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'OSEE Prep Hub';

  @override
  String get navHome => 'Beranda';

  @override
  String get navSyllabus => 'Silabus';

  @override
  String get navStudents => 'Siswa';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSettings => 'Pengaturan';

  @override
  String get navDashboard => 'Dasbor';

  @override
  String get navMaterials => 'Materi';

  @override
  String get navReports => 'Laporan';

  @override
  String get navClasses => 'Kelas';

  @override
  String get navOrders => 'Pesanan';

  @override
  String get navCommission => 'Komisi';

  @override
  String get navPartner => 'Mitra';

  @override
  String get navAmbassador => 'Duta';

  @override
  String get navAdmin => 'Admin';

  @override
  String get authLogin => 'Masuk';

  @override
  String get authRegister => 'Daftar';

  @override
  String get authLogout => 'Keluar';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Kata sandi';

  @override
  String get authConfirmPassword => 'Konfirmasi kata sandi';

  @override
  String get authDisplayName => 'Nama tampilan';

  @override
  String get authForgotPassword => 'Lupa kata sandi?';

  @override
  String get authReferralCode => 'Kode referral';

  @override
  String get authRoleStudent => 'Siswa';

  @override
  String get authRoleTeacher => 'Pengajar';

  @override
  String get authRolePartner => 'Mitra';

  @override
  String get authRoleAdmin => 'Admin';

  @override
  String get authLoginSuccess => 'Berhasil masuk';

  @override
  String get authLoginFailed => 'Masuk gagal';

  @override
  String get authRegisterSuccess => 'Akun dibuat';

  @override
  String get authRegisterFailed => 'Pendaftaran gagal';

  @override
  String get authPasswordMismatch => 'Kata sandi tidak cocok';

  @override
  String get authEmailRequired => 'Email wajib diisi';

  @override
  String get authPasswordRequired => 'Kata sandi wajib diisi';

  @override
  String get authInvalidEmail => 'Format email tidak valid';

  @override
  String get authPasswordTooShort => 'Kata sandi minimal 8 karakter';

  @override
  String get authAccountExists => 'Akun dengan email ini sudah ada';

  @override
  String dashboardWelcome(String name) {
    return 'Selamat datang, $name!';
  }

  @override
  String get dashboardStats => 'Statistik Anda';

  @override
  String get dashboardRecentActivity => 'Aktivitas terbaru';

  @override
  String get dashboardQuickActions => 'Aksi cepat';

  @override
  String get dashboardUpcomingClasses => 'Kelas mendatang';

  @override
  String get dashboardPendingGrading => 'Menunggu penilaian';

  @override
  String get dashboardActiveStudents => 'Siswa aktif';

  @override
  String get dashboardRevenue => 'Pendapatan';

  @override
  String get dashboardWeeklyProgress => 'Progres mingguan';

  @override
  String get dashboardNoActivity => 'Tidak ada aktivitas terbaru';

  @override
  String get syllabusNew => 'Silabus baru';

  @override
  String get syllabusEdit => 'Edit silabus';

  @override
  String get syllabusShare => 'Bagikan silabus';

  @override
  String get syllabusDelete => 'Hapus silabus';

  @override
  String get syllabusDuplicate => 'Duplikat silabus';

  @override
  String get syllabusTitle => 'Judul silabus';

  @override
  String get syllabusDescription => 'Deskripsi';

  @override
  String get syllabusTargetExam => 'Ujian target';

  @override
  String get syllabusTargetScore => 'Skor target';

  @override
  String get syllabusWeeks => 'Minggu';

  @override
  String get syllabusItems => 'Item';

  @override
  String get syllabusAddItem => 'Tambah item';

  @override
  String get syllabusRemoveItem => 'Hapus item';

  @override
  String get syllabusMoveUp => 'Pindah naik';

  @override
  String get syllabusMoveDown => 'Pindah turun';

  @override
  String get syllabusPublish => 'Terbitkan';

  @override
  String get syllabusUnpublish => 'Batalkan terbit';

  @override
  String get syllabusPublished => 'Diterbitkan';

  @override
  String get syllabusDraft => 'Draf';

  @override
  String get syllabusTemplate => 'Templat';

  @override
  String get syllabusAssign => 'Tugaskan ke kelas';

  @override
  String get syllabusAssigned => 'Ditugaskan';

  @override
  String get syllabusEmpty => 'Belum ada silabus. Buat yang pertama.';

  @override
  String syllabusWeekLabel(int n) {
    return 'Minggu $n';
  }

  @override
  String get studentAdd => 'Tambah siswa';

  @override
  String get studentEdit => 'Edit siswa';

  @override
  String get studentRemove => 'Hapus siswa';

  @override
  String get studentProgress => 'Progres';

  @override
  String studentProgressPct(int pct) {
    return '$pct% selesai';
  }

  @override
  String get studentScore => 'Skor';

  @override
  String get studentBand => 'Band';

  @override
  String get studentLevel => 'Level';

  @override
  String get studentReadiness => 'Kesiapan';

  @override
  String get studentLastActive => 'Terakhir aktif';

  @override
  String get studentCurrentSyllabus => 'Silabus saat ini';

  @override
  String get studentWeakAreas => 'Area lemah';

  @override
  String get studentStrongAreas => 'Area kuat';

  @override
  String get studentNoData => 'Belum ada data';

  @override
  String get commonSave => 'Simpan';

  @override
  String get commonCancel => 'Batal';

  @override
  String get commonDelete => 'Hapus';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Tutup';

  @override
  String get commonRetry => 'Coba lagi';

  @override
  String get commonLoading => 'Memuat...';

  @override
  String get commonError => 'Error';

  @override
  String get commonSuccess => 'Berhasil';

  @override
  String get commonWarning => 'Peringatan';

  @override
  String get commonConfirm => 'Konfirmasi';

  @override
  String get commonYes => 'Ya';

  @override
  String get commonNo => 'Tidak';

  @override
  String get commonSearch => 'Cari';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonSort => 'Urutkan';

  @override
  String get commonRefresh => 'Segarkan';

  @override
  String get commonNext => 'Berikutnya';

  @override
  String get commonPrevious => 'Sebelumnya';

  @override
  String get commonFinish => 'Selesai';

  @override
  String get commonSubmit => 'Kirim';

  @override
  String get commonReset => 'Atur ulang';

  @override
  String get commonApply => 'Terapkan';

  @override
  String get commonOK => 'OK';

  @override
  String get commonActions => 'Aksi';

  @override
  String get commonStatus => 'Status';

  @override
  String get commonDate => 'Tanggal';

  @override
  String get commonTime => 'Waktu';

  @override
  String get commonDuration => 'Durasi';

  @override
  String get commonName => 'Nama';

  @override
  String get commonEmail => 'Email';

  @override
  String get commonRole => 'Peran';

  @override
  String get commonType => 'Tipe';

  @override
  String get commonTitle => 'Judul';

  @override
  String get commonDescription => 'Deskripsi';

  @override
  String get commonNotes => 'Catatan';

  @override
  String get commonCreated => 'Dibuat';

  @override
  String get commonUpdated => 'Diperbarui';

  @override
  String get commonBy => 'Oleh';

  @override
  String get commonFor => 'Untuk';

  @override
  String get commonFrom => 'Dari';

  @override
  String get commonTo => 'Ke';

  @override
  String get commonAll => 'Semua';

  @override
  String get commonNone => 'Tidak ada';

  @override
  String get commonOptional => 'Opsional';

  @override
  String get commonRequired => 'Wajib';

  @override
  String get commonPending => 'Tertunda';

  @override
  String get commonActive => 'Aktif';

  @override
  String get commonInactive => 'Tidak aktif';

  @override
  String get commonComplete => 'Selesai';

  @override
  String get commonIncomplete => 'Belum selesai';

  @override
  String get commonEnabled => 'Aktif';

  @override
  String get commonDisabled => 'Nonaktif';

  @override
  String get commonOnline => 'Online';

  @override
  String get commonOffline => 'Offline';

  @override
  String get commonConnecting => 'Menghubungkan...';

  @override
  String get commonReconnecting => 'Menghubungkan ulang...';

  @override
  String get commonConnectionLost => 'Koneksi terputus';

  @override
  String get commonConnectionRestored => 'Koneksi dipulihkan';

  @override
  String get commonSyncing => 'Menyinkronkan...';

  @override
  String get commonSynced => 'Tersinkron';

  @override
  String get commonSyncFailed => 'Sinkronisasi gagal';

  @override
  String get commonOfflineMode => 'Mode offline';

  @override
  String get commonOnlineMode => 'Mode online';

  @override
  String get commonRetrySync => 'Coba sinkron ulang';

  @override
  String commonChangesQueued(int count) {
    return '$count perubahan menunggu sinkron';
  }

  @override
  String get errorGeneric => 'Terjadi kesalahan';

  @override
  String get errorNetwork => 'Kesalahan jaringan';

  @override
  String get errorNotFound => 'Tidak ditemukan';

  @override
  String get errorUnauthorized => 'Tidak memiliki izin';

  @override
  String get errorForbidden => 'Dilarang';

  @override
  String get errorServerError => 'Kesalahan server';

  @override
  String get errorValidation => 'Kesalahan validasi';

  @override
  String get errorTimeout => 'Permintaan waktu habis';

  @override
  String get errorOffline => 'Anda sedang offline';

  @override
  String get errorRateLimited => 'Terlalu banyak permintaan. Mohon tunggu.';

  @override
  String get settingsLanguage => 'Bahasa';

  @override
  String get settingsEnglish => 'English';

  @override
  String get settingsBahasa => 'Bahasa Indonesia';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeLight => 'Terang';

  @override
  String get settingsThemeDark => 'Gelap';

  @override
  String get settingsNotifications => 'Notifikasi';

  @override
  String get settingsAccount => 'Akun';

  @override
  String get settingsPrivacy => 'Privasi';

  @override
  String get settingsAbout => 'Tentang';

  @override
  String get settingsVersion => 'Versi';

  @override
  String get settingsSignOut => 'Keluar';

  @override
  String get settingsDeleteAccount => 'Hapus akun';
}
