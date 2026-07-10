/** Bahasa Indonesia i18n bundle — Task 4 (Wave 1). */
export const id = {
  'auth.login_success': 'Berhasil masuk',
  'auth.login_failed': 'Masuk gagal',
  'auth.register_success': 'Akun dibuat',
  'auth.register_failed': 'Pendaftaran gagal',
  'auth.account_exists': 'Akun dengan email ini sudah ada',
  'auth.invalid_token': 'Token tidak valid atau kedaluwarsa',
  'auth.unauthorized': 'Diperlukan autentikasi',
  'auth.forbidden': 'Anda tidak memiliki izin untuk ini',
  'auth.password_too_short': 'Kata sandi minimal 8 karakter',
  'auth.invalid_email': 'Format email tidak valid',

  'syllabus.not_found': 'Silabus tidak ditemukan',
  'syllabus.not_owner': 'Hanya pemilik silabus yang dapat melakukan ini',
  'syllabus.already_published': 'Silabus sudah diterbitkan',
  'syllabus.has_collaborators': 'Tidak dapat menghapus silabus dengan kolaborator aktif',

  'passport.issue_failed': 'Gagal menerbitkan kredensial',
  'passport.not_found': 'Kredensial tidak ditemukan',
  'passport.revoked': 'Kredensial telah dicabut',
  'passport.signature_invalid': 'Tanda tangan kredensial tidak valid',
  'passport.key_unavailable': 'Kunci penandatanganan Passport belum dikonfigurasi',
  'passport.only_issuer_can_revoke': 'Hanya penerbit asli atau admin yang dapat mencabut',

  'agent.not_found': 'Agent tidak dikenal',
  'agent.failed': 'Pemanggilan agent gagal',
  'agent.input_required': 'input diperlukan',
  'agent.input_too_long': 'input maksimal 4000 karakter',
  'agent.rate_limited': 'Batas permintaan tercapai. Coba lagi dalam satu menit.',

  'order.not_found': 'Pesanan tidak ditemukan',
  'order.payment_required': 'Pembayaran diperlukan untuk memenuhi pesanan ini',
  'order.already_paid': 'Pesanan sudah dibayar',
  'order.cannot_cancel': 'Tidak dapat membatalkan pesanan yang sudah dipenuhi',

  'marketplace.listing_not_found': 'Iklan tidak ditemukan',
  'marketplace.already_purchased': 'Anda sudah membeli item ini',
  'marketplace.seller_cannot_buy': 'Anda tidak dapat membeli iklan Anda sendiri',

  'common.bad_request': 'Permintaan tidak valid',
  'common.internal_error': 'Terjadi kesalahan tak terduga',
  'common.not_found': 'Tidak ditemukan',
  'common.rate_limited': 'Terlalu banyak permintaan',
} as Record<string, string>;