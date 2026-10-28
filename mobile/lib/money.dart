import 'package:intl/intl.dart';

const manilaOffset = Duration(hours: 8);

DateTime toManila(DateTime value) {
  return value.toUtc().add(manilaOffset);
}

String manilaToday() {
  final date = toManila(DateTime.now());
  return DateFormat('yyyy-MM-dd').format(date);
}

int manilaYear([DateTime? value]) {
  return toManila(value ?? DateTime.now()).year;
}

int manilaMonth([DateTime? value]) {
  return toManila(value ?? DateTime.now()).month;
}

String peso(num? value) {
  return NumberFormat.currency(locale: 'en_PH', symbol: '₱').format(value ?? 0);
}

String formatDate(DateTime value) {
  return DateFormat('MMM d, h:mm a').format(toManila(value));
}

String weekdayShort(String date) {
  final parsed = DateTime.tryParse('${date}T12:00:00+08:00') ?? DateTime.tryParse(date);
  if (parsed == null) return date;
  return DateFormat('E').format(toManila(parsed));
}

String axisLabel(num value) {
  if (value >= 1000) {
    final thousands = value / 1000;
    final label = thousands == thousands.roundToDouble()
        ? thousands.toStringAsFixed(0)
        : thousands.toStringAsFixed(1);
    return '₱${label}k';
  }
  return '₱${value.round()}';
}

double niceCeil(num value) {
  if (value <= 0) return 100;
  final log10 = (value.toDouble()).log10Floor();
  final pow = _pow10(log10);
  final n = value / pow;
  final nice = n <= 1
      ? 1
      : n <= 2
      ? 2
      : n <= 5
      ? 5
      : 10;
  return nice * pow;
}

double _pow10(int exp) {
  var result = 1.0;
  for (var i = 0; i < exp; i++) {
    result *= 10;
  }
  return result;
}

extension on double {
  int log10Floor() {
    if (this <= 0) return 0;
    var n = this;
    var exp = 0;
    while (n >= 10) {
      n /= 10;
      exp++;
    }
    while (n < 1) {
      n *= 10;
      exp--;
    }
    return exp;
  }
}
