const _rupiahFormatter = new Intl.NumberFormat('id-ID', {
  style: 'currency',
  currency: 'IDR',
  maximumFractionDigits: 0,
});

/** Format a number as Indonesian Rupiah currency (e.g. 75000 → "Rp 75.000"). */
export function formatRupiah(value: number): string {
  return _rupiahFormatter.format(value);
}