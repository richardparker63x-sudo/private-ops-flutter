import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kBlue = Color(0xFF2563EB), kSky = Color(0xFF38BDF8), kGreen = Color(0xFF0F9D6E), kRed = Color(0xFFE5484D);
final mk = GlobalKey<ScaffoldMessengerState>();
void toast(String m) => mk.currentState?.showSnackBar(SnackBar(content: Text(m)));
String hash(String s) => sha256.convert(utf8.encode(s)).toString();
String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String today() => ymd(DateTime.now());
String ago(int n) => ymd(DateTime.now().subtract(Duration(days: n)));
double sum(Iterable l, String k) => l.fold<double>(0, (a, x) => a + ((x[k] ?? 0) as num));
Iterable ofType(Iterable l, String ty) => l.where((x) => x['type'] == ty);
String tr(String en, String bn) => S.bn ? bn : en;
String money(num n) => '৳${NumberFormat.decimalPattern(S.bn ? 'bn' : 'en_IN').format(n.round())}';
Widget live(Widget Function() b) => ListenableBuilder(listenable: S, builder: (_, __) => b());
void go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

class Store extends ChangeNotifier {
  late SharedPreferences sp;
  Map<String, dynamic> d = {};
  Future<void> load() async {
    sp = await SharedPreferences.getInstance();
    final s = sp.getString('pbo_native');
    d = s != null ? jsonDecode(s) : fresh();
  }
  Map<String, dynamic> fresh() => {
        'biz': [], 'mem': [{'id': 'u0', 'name': 'Admin', 'role': 'admin', 'biz': 'all'}],
        'tx': [], 'priv': [], 'log': [], 'me': 'u0', 'in': false, 'n': 1, 'lang': 'en', 'theme': 'system', 'target': 0
      };
  void save() { sp.setString('pbo_native', jsonEncode(d)); notifyListeners(); }
  void ping() => notifyListeners();
  List get biz => d['biz'];
  List get mem => d['mem'];
  List get tx => d['tx'];
  List get priv => d['priv'];
  List get logs => d['log'];
  bool get bn => d['lang'] == 'bn';
  Map get me => mem.firstWhere((m) => m['id'] == d['me'], orElse: () => mem.first);
  bool get admin => me['role'] == 'admin';
  String nm(List l, String? id) { for (final x in l) { if (x['id'] == id) return x['name'] as String; } return '—'; }
  void log(String m) { logs.insert(0, {'t': DateTime.now().toString().substring(0, 16), 'u': me['name'], 'm': m}); if (logs.length > 80) logs.removeRange(80, logs.length); }
  double bal(String b) {
    final a = tx.where((t) => t['biz'] == b);
    return sum(ofType(a, 'work'), 'paid') - sum(ofType(a, 'exp'), 'amount') -
        sum(ofType(a, 'inv').where((t) => t['src'] == 'Business balance'), 'amount') +
        sum(ofType(a, 'cap'), 'amount') - sum(ofType(a, 'ret'), 'amount');
  }
  List vis() => tx.where((t) => (admin || t['by'] == d['me'] || t['to'] == d['me']) && (F.biz == 'all' || t['biz'] == F.biz)).toList();
}
final S = Store();

class Filt {
  String r = 'month', from = ago(30), to = today(), biz = 'all';
  bool ok(String d) {
    switch (r) {
      case 'all': return true;
      case 'today': return d == today();
      case 'week': return d.compareTo(ago(6)) >= 0;
      case 'month': return d.substring(0, 7) == today().substring(0, 7);
      default: return d.compareTo(from) >= 0 && d.compareTo(to) <= 0;
    }
  }
}
final F = Filt(), PF = Filt();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await S.load();
  runApp(const OpsApp());
}

class OpsApp extends StatelessWidget {
  const OpsApp({super.key});
  ThemeData th(Brightness b) {
    final dark = b == Brightness.dark;
    final cs = ColorScheme.fromSeed(seedColor: kBlue, brightness: b).copyWith(primary: dark ? const Color(0xFF5B9CFF) : kBlue, surface: dark ? const Color(0xFF0D2042) : Colors.white);
    return ThemeData(
      useMaterial3: true, colorScheme: cs,
      scaffoldBackgroundColor: dark ? const Color(0xFF061226) : const Color(0xFFF0F6FF),
      appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: dark ? const Color(0xFF0A1A37) : const Color(0xFFF0F6FF), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: cs.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14))),
      bottomAppBarTheme: BottomAppBarTheme(color: cs.surface, surfaceTintColor: Colors.transparent),
    );
  }
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: S,
        builder: (_, __) {
          final tm = S.d['theme'] == 'dark' ? ThemeMode.dark : S.d['theme'] == 'light' ? ThemeMode.light : ThemeMode.system;
          final needAuth = S.mem[0]['pw'] == null || S.d['in'] != true;
          return MaterialApp(
            scaffoldMessengerKey: mk, debugShowCheckedModeBanner: false, title: 'Private Ops',
            theme: th(Brightness.light), darkTheme: th(Brightness.dark), themeMode: tm,
            home: needAuth ? const Gate() : const Shell(),
          );
        },
      );
}

// ---------- shared widgets ----------
Widget card(Widget ch, {EdgeInsets p = const EdgeInsets.all(16)}) => Builder(builder: (c) {
      final cs = Theme.of(c).colorScheme;
      return Container(
        width: double.infinity, padding: p,
        decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant.withOpacity(.5)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 16, offset: const Offset(0, 6))]),
        child: ch,
      );
    });
Widget sec(String s) => Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 10), child: Text(s, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)));
Widget pic(String? data, double s, Widget fallback) => ClipRRect(
      borderRadius: BorderRadius.circular(s * .32),
      child: Container(width: s, height: s, color: kBlue.withOpacity(.12),
          child: (data != null && data.isNotEmpty) ? Image.memory(base64Decode(data), fit: BoxFit.cover) : Center(child: fallback)),
    );
Widget av(Map m, {double s = 40}) {
  final n = (m['name'] ?? '?') as String;
  return pic(m['photo'] as String?, s, Text(n.isEmpty ? '?' : n[0].toUpperCase(), style: TextStyle(color: kBlue, fontWeight: FontWeight.w700, fontSize: s * .4)));
}
Widget logo(Map b, {double s = 40}) => pic(b['logo'] as String?, s, Icon(Icons.business_center_rounded, color: kBlue, size: s * .5));
Widget empty(IconData ic, String title, String sub, {String? btn, VoidCallback? on}) => card(Column(children: [
      Icon(ic, size: 44, color: kBlue), const SizedBox(height: 10),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16), textAlign: TextAlign.center),
      if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))),
      if (btn != null) Padding(padding: const EdgeInsets.only(top: 14), child: FilledButton(onPressed: on, child: Text(btn))),
    ]));
Widget stat(String k, String v, {Color? c}) => card(
    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(k, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c))),
    ]), p: const EdgeInsets.all(14));
Widget grid2(List<Widget> ch, {int n = 2, double r = 2.0}) => GridView.count(crossAxisCount: n, childAspectRatio: r, mainAxisSpacing: 10, crossAxisSpacing: 10, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: ch);
Future<bool> confirm(BuildContext c, String msg) async => (await showDialog<bool>(context: c, builder: (_) => AlertDialog(title: Text(msg), actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel', 'বাতিল'))),
      TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Delete', 'মুছুন'), style: const TextStyle(color: kRed)))])) ?? false);
Future<String?> pickPhoto() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 256, maxHeight: 256, imageQuality: 80);
  return x == null ? null : base64Encode(await x.readAsBytes());
}
Future<void> shareFile(String name, String data) async {
  final d = await getTemporaryDirectory();
  final f = File('${d.path}/$name');
  await f.writeAsString(data);
  await Share.shareXFiles([XFile(f.path)]);
}

class Bars extends CustomPainter {
  final Map<String, double> d; final Color col, txt;
  Bars(this.d, this.col, this.txt);
  void _tx(Canvas cv, String s, Offset c) {
    final p = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: 9, color: txt)), textDirection: TextDirection.ltr)..layout();
    p.paint(cv, Offset(c.dx - p.width / 2, c.dy));
  }
  @override
  void paint(Canvas cv, Size s) {
    final ks = d.keys.toList()..sort();
    final k = ks.length > 14 ? ks.sublist(ks.length - 14) : ks;
    if (k.isEmpty) return;
    final mx = k.map((e) => d[e]!).reduce(math.max);
    final w = s.width / k.length;
    for (var i = 0; i < k.length; i++) {
      final h = math.max(d[k[i]]! / (mx == 0 ? 1 : mx) * (s.height - 44), 3.0);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(i * w + w * .18, s.height - 20 - h, w * .64, h), const Radius.circular(5));
      cv.drawRRect(r, Paint()..color = k[i] == today() ? col : col.withOpacity(.5));
      _tx(cv, k[i].substring(8), Offset(i * w + w / 2, s.height - 14));
      _tx(cv, d[k[i]]!.round().toString(), Offset(i * w + w / 2, s.height - 34 - h));
    }
  }
  @override
  bool shouldRepaint(_) => true;
}
Widget chart(BuildContext c, Iterable rows, String key) {
  final m = <String, double>{};
  for (final t in rows) { m[t['date']] = (m[t['date']] ?? 0) + (t[key] as num); }
  if (m.isEmpty) return Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(tr('No income in this period', 'এই সময়ে কোনো ইনকাম নেই'), style: const TextStyle(color: Colors.grey))));
  return SizedBox(height: 150, width: double.infinity, child: CustomPaint(painter: Bars(m, Theme.of(c).colorScheme.primary, Colors.grey)));
}
Widget monthly(Iterable a) {
  final m = <String, List<double>>{};
  for (final t in a) {
    final k = (t['date'] as String).substring(0, 7);
    m.putIfAbsent(k, () => [0, 0]);
    if (t['type'] == 'work') m[k]![0] += (t['paid'] as num);
    if (t['type'] == 'exp') m[k]![1] += (t['amount'] as num);
  }
  if (m.isEmpty) return Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(tr('No data yet', 'এখনো কোনো ডেটা নেই'))));
  final ks = m.keys.toList()..sort((x, y) => y.compareTo(x));
  return Column(children: [for (final k in ks) ListTile(contentPadding: EdgeInsets.zero, title: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${tr('Income', 'ইনকাম')} ${money(m[k]![0])} · ${tr('Expense', 'খরচ')} ${money(m[k]![1])}'),
      trailing: Text(money(m[k]![0] - m[k]![1]), style: TextStyle(fontWeight: FontWeight.w800, color: m[k]![0] - m[k]![1] < 0 ? kRed : kGreen)))]);
}

class FilterBar extends StatelessWidget {
  final Filt f; final bool biz;
  const FilterBar(this.f, {this.biz = true, super.key});
  @override
  Widget build(BuildContext c) {
    final o = [['today', 'Today', 'আজ'], ['week', '7 days', '৭ দিন'], ['month', 'Month', 'মাস'], ['all', 'All', 'সব'], ['custom', 'Custom', 'কাস্টম']];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        for (final x in o) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(tr(x[1], x[2])), selected: f.r == x[0], onSelected: (_) async {
          if (x[0] == 'custom') {
            final r = await showDateRangePicker(context: c, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (r == null) return;
            f.from = ymd(r.start); f.to = ymd(r.end);
          }
          f.r = x[0]; S.ping();
        }))])),
      if (f.r == 'custom') Padding(padding: const EdgeInsets.only(top: 6), child: Text('${f.from} → ${f.to}', style: const TextStyle(fontSize: 12, color: Colors.grey))),
      if (biz && S.admin && S.biz.length > 1) Padding(padding: const EdgeInsets.only(top: 8), child: DropdownButton<String>(value: f.biz, isDense: true, underline: const SizedBox(),
          items: [DropdownMenuItem(value: 'all', child: Text(tr('All businesses', 'সব ব্যবসা'))), for (final b in S.biz) DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] as String))],
          onChanged: (v) { f.biz = v!; S.ping(); })),
    ]);
  }
}

// ---------- transaction rows ----------
const tIcon = {'work': Icons.edit_note_rounded, 'inv': Icons.trending_up_rounded, 'exp': Icons.receipt_long_rounded, 'xfer': Icons.swap_horiz_rounded, 'cap': Icons.add_card_rounded, 'ret': Icons.undo_rounded};
const tCol = {'work': kBlue, 'inv': Color(0xFFC98A1B), 'exp': kRed, 'xfer': Color(0xFF6366F1), 'cap': kGreen, 'ret': Color(0xFFE07B39)};
String descr(Map x) {
  final k = x['type'];
  if (k == 'work') return '${x['plat']} · ${x['cat']}';
  if (k == 'cap' || k == 'ret') return '${S.nm(S.mem, x['by'])} · ${k == 'ret' ? tr('Repayment', 'ফেরত') : x['mode'] == 'Equity' ? tr('Equity', 'ইকুইটি') : tr('Loan', 'লোন')}';
  if (k == 'xfer') return '${S.nm(S.mem, x['by'])} → ${S.nm(S.mem, x['to'])}';
  return '${x['cat'] ?? ''}${(x['to'] ?? '').toString().isNotEmpty ? ' → ${x['to']}' : ''}';
}
Widget txRow(BuildContext c, Map x, {bool act = false}) {
  final due = x['type'] == 'work' ? (x['amount'] as num) - (x['paid'] as num) : 0;
  final col = tCol[x['type']] ?? kBlue;
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: col.withOpacity(.12), borderRadius: BorderRadius.circular(13)), child: Icon(tIcon[x['type']], color: col, size: 21)),
    title: Text(descr(x), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text('${x['date']} · ${S.nm(S.biz, x['biz'])}${(x['note'] ?? '').toString().isNotEmpty ? ' · ${x['note']}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('${x['type'] == 'exp' ? '−' : ''}${money(x['amount'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
      if (due > 0) Text('${tr('Due', 'বাকি')} ${money(due)}', style: const TextStyle(fontSize: 11, color: kRed)),
    ]),
    onTap: act ? () => txMenu(c, x, due > 0) : null,
  );
}
void txMenu(BuildContext c, Map x, bool due) => showModalBottomSheet(context: c, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (due) ListTile(leading: const Icon(Icons.payments_rounded), title: Text(tr('Collect payment', 'টাকা নিন')), onTap: () { Navigator.pop(c); openForm(c, 'pay', pre: {'pid': x['id'], 'amount': (x['amount'] as num) - (x['paid'] as num)}); }),
      ListTile(leading: const Icon(Icons.delete_outline_rounded, color: kRed), title: Text(tr('Delete', 'মুছুন'), style: const TextStyle(color: kRed)), onTap: () async {
        Navigator.pop(c);
        if (await confirm(c, tr('Delete this record?', 'রেকর্ডটি মুছবেন?'))) { S.tx.removeWhere((t) => t['id'] == x['id']); S.log('deleted record'); S.save(); }
      }),
    ])));

class TxList extends StatefulWidget {
  final List<String> types; final bool due; final String? add;
  const TxList(this.types, {this.due = false, this.add, super.key});
  @override
  State<TxList> createState() => _TL();
}
class _TL extends State<TxList> {
  String q = '';
  @override
  Widget build(BuildContext c) => live(() {
        final a = S.vis().where((t) => F.ok(t['date']) && widget.types.contains(t['type']) && (!widget.due || (t['amount'] as num) > (t['paid'] as num)) && (q.isEmpty || jsonEncode(t).toLowerCase().contains(q))).toList()
          ..sort((x, y) => (y['id'] as int).compareTo(x['id'] as int));
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          FilterBar(F), const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(decoration: InputDecoration(hintText: tr('Search…', 'খুঁজুন…'), prefixIcon: const Icon(Icons.search_rounded)), onChanged: (v) => setState(() => q = v.toLowerCase()))),
            const SizedBox(width: 8),
            IconButton.filledTonal(onPressed: () => exportCsv(a), icon: const Icon(Icons.download_rounded)),
          ]),
          if (widget.add != null && S.biz.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: FilledButton.icon(onPressed: () => openForm(c, widget.add!), icon: const Icon(Icons.add_rounded), label: Text(tr('Add new', 'নতুন যোগ করুন')))),
          const SizedBox(height: 10),
          a.isEmpty ? empty(Icons.inbox_rounded, tr('Nothing here', 'এখানে কিছু নেই'), tr('Try another period or add a record.', 'অন্য সময় বেছে নিন বা নতুন রেকর্ড যোগ করুন।'))
              : card(Column(children: [for (final x in a) txRow(c, x, act: true)]), p: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
        ]);
      });
}
String q(dynamic e) => '"${e.toString().replaceAll('"', '""')}"';
Future<void> exportCsv(List rows) async {
  final b = StringBuffer('\uFEFFdate,type,business,category,amount,received,note\n');
  for (final x in rows) { b.writeln([x['date'], x['type'], S.nm(S.biz, x['biz']), x['cat'] ?? x['to'] ?? '', x['amount'], x['paid'] ?? '', x['note'] ?? ''].map(q).join(',')); }
  await shareFile('records.csv', b.toString());
}

// ---------- shell ----------
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _SH();
}
class _SH extends State<Shell> {
  int i = 0;
  Widget nav(int n, IconData ic, String l) => Expanded(child: InkWell(onTap: () => setState(() => i = n), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, color: i == n ? kBlue : Colors.grey), Text(l, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: i == n ? kBlue : Colors.grey))]))));
  @override
  Widget build(BuildContext c) => live(() => Scaffold(
        body: SafeArea(child: IndexedStack(index: i, children: const [HomePage(), ActivityPage(), ReportsPage(), ProfilePage()])),
        floatingActionButton: FloatingActionButton(onPressed: () => quick(c), backgroundColor: kBlue, foregroundColor: Colors.white, shape: const CircleBorder(), child: const Icon(Icons.add_rounded, size: 30)),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(shape: const CircularNotchedRectangle(), notchMargin: 8, height: 64, padding: EdgeInsets.zero, child: Row(children: [
          nav(0, Icons.home_rounded, tr('Home', 'হোম')), nav(1, Icons.receipt_long_rounded, tr('Activity', 'লেনদেন')),
          const SizedBox(width: 64),
          nav(2, Icons.bar_chart_rounded, tr('Reports', 'রিপোর্ট')), nav(3, Icons.person_rounded, tr('Profile', 'প্রোফাইল'))])),
      ));
}
void quick(BuildContext c) {
  if (S.biz.isEmpty) { toast(tr('Create a business first', 'আগে ব্যবসা তৈরি করুন')); return; }
  final o = [['work', Icons.edit_note_rounded, 'Work', 'কাজ'], ['exp', Icons.receipt_long_rounded, 'Expense', 'খরচ'], ['inv', Icons.trending_up_rounded, 'Investment', 'বিনিয়োগ'],
    ['xfer', Icons.swap_horiz_rounded, 'Transfer', 'ট্রান্সফার'], ['cap', Icons.add_card_rounded, 'My money in', 'নিজের টাকা দিন'], ['pi', Icons.lock_rounded, 'Private', 'প্রাইভেট']];
  showModalBottomSheet(context: c, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(tr('Quick add', 'দ্রুত যোগ'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 14),
        grid2([for (final x in o) InkWell(borderRadius: BorderRadius.circular(16), onTap: () { Navigator.pop(c); openForm(c, x[0] as String); },
            child: Container(decoration: BoxDecoration(color: kBlue.withOpacity(.08), borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(x[1] as IconData, color: kBlue), const SizedBox(width: 8), Text(tr(x[2] as String, x[3] as String), style: const TextStyle(fontWeight: FontWeight.w600))])))], r: 2.6),
      ]))));
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});
  @override
  Widget build(BuildContext c) => live(() => Scaffold(appBar: AppBar(title: Text(tr('Transactions', 'লেনদেন'))), body: const TxList(['work', 'inv', 'exp', 'xfer', 'cap', 'ret'])));
}

// ---------- home ----------
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext c) => live(() {
        final v = S.vis(), a = v.where((t) => F.ok(t['date'])).toList(), w = ofType(a, 'work').toList();
        final inc = sum(w, 'paid'), ex = sum(ofType(a, 'exp'), 'amount');
        final td = sum(ofType(v, 'work').where((t) => t['date'] == today()), 'paid');
        final days = <String, double>{};
        for (final t in w) { days[t['date']] = (days[t['date']] ?? 0) + (t['paid'] as num); }
        final best = days.values.fold<double>(0, math.max);
        final bs = F.biz == 'all' ? S.biz : S.biz.where((b) => b['id'] == F.biz).toList();
        final mi = sum(ofType(v, 'work').where((t) => (t['date'] as String).substring(0, 7) == today().substring(0, 7)), 'paid');
        final tg = (S.d['target'] as num).toDouble();
        final sv = <List>[['work', Icons.edit_note_rounded, 'Work', 'কাজ'], ['exp', Icons.receipt_long_rounded, 'Expenses', 'খরচ'], ['inv', Icons.trending_up_rounded, 'Invest', 'বিনিয়োগ'], ['xfer', Icons.swap_horiz_rounded, 'Transfers', 'ট্রান্সফার'],
          ['due', Icons.hourglass_bottom_rounded, 'Due', 'বাকি'], ['cap', Icons.account_balance_wallet_rounded, 'Partner funds', 'পার্টনার ফান্ড'], ['priv', Icons.lock_rounded, 'Private', 'প্রাইভেট'], ['biz', Icons.business_center_rounded, 'Business', 'ব্যবসা'],
          if (S.admin) ['mem', Icons.group_rounded, 'Members', 'সদস্য'], ['rep', Icons.bar_chart_rounded, 'Reports', 'রিপোর্ট'], ['log', Icons.history_rounded, 'Activity', 'অ্যাক্টিভিটি'], ['set', Icons.settings_rounded, 'Settings', 'সেটিংস']];
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
          Row(children: [
            GestureDetector(onTap: () => go(c, const ProfilePage(own: true)), child: av(S.me, s: 44)), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tr('Hello', 'হ্যালো'), style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(S.me['name'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))])),
            TextButton(onPressed: () { S.d['lang'] = S.bn ? 'en' : 'bn'; S.save(); }, child: Text(S.bn ? 'EN' : 'বাং')),
            IconButton(onPressed: () { final dk = Theme.of(c).brightness == Brightness.dark; S.d['theme'] = dk ? 'light' : 'dark'; S.save(); }, icon: Icon(Theme.of(c).brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
          ]),
          const SizedBox(height: 14),
          if (S.biz.isEmpty) empty(Icons.business_center_rounded, tr('Start with your first business', 'প্রথম ব্যবসা দিয়ে শুরু করুন'), tr('Create a workspace, then add work and expenses.', 'একটি ওয়ার্কস্পেস খুলুন, তারপর কাজ ও খরচ যোগ করুন।'), btn: tr('Create business', 'ব্যবসা তৈরি করুন'), on: () => openForm(c, 'biz'))
          else ...[
            FilterBar(F), const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF2F80FF), Color(0xFF4CC3FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: kBlue.withOpacity(.35), blurRadius: 24, offset: const Offset(0, 10))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(tr('Today’s income', 'আজকের ইনকাম'), style: const TextStyle(color: Colors.white70)),
                InkWell(onTap: () => Share.share('${tr('Daily report', 'দৈনিক রিপোর্ট')} ${today()}\n${tr('Income', 'ইনকাম')}: ${money(td)}\n${tr('Expense', 'খরচ')}: ${money(sum(ofType(v, 'exp').where((t) => t['date'] == today()), 'amount'))}\n${tr('Due', 'বাকি')}: ${money(sum(w, 'amount') - inc)}'), child: const Icon(Icons.ios_share_rounded, color: Colors.white))]),
              const SizedBox(height: 4),
              Text(money(td), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)), const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final p in [[tr('This period', 'এই সময়ে'), inc], [tr('Avg / day', 'গড় / দিন'), days.isEmpty ? 0 : inc / days.length], [tr('Best day', 'সেরা দিন'), best]])
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p[0] as String, style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(money(p[1] as num), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))])]),
            ])),
            if (tg > 0) Padding(padding: const EdgeInsets.only(top: 12), child: card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(tr('Monthly target', 'মাসিক টার্গেট'), style: const TextStyle(fontWeight: FontWeight.w700)), Text('${money(mi)} / ${money(tg)}', style: const TextStyle(fontSize: 12, color: Colors.grey))]),
              const SizedBox(height: 10), LinearProgressIndicator(value: (mi / tg).clamp(0, 1).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(8))]))),
            sec(tr('Services', 'সার্ভিস')),
            GridView.count(crossAxisCount: 4, childAspectRatio: .82, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: [for (final x in sv)
              InkWell(borderRadius: BorderRadius.circular(16), onTap: () => openPage(c, x[0] as String), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 52, height: 52, decoration: BoxDecoration(color: kBlue.withOpacity(.1), borderRadius: BorderRadius.circular(16)), child: Icon(x[1] as IconData, color: kBlue)), const SizedBox(height: 6),
                Text(tr(x[2] as String, x[3] as String), textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))]))]),
            sec(tr('Overview', 'সারসংক্ষেপ')),
            grid2([stat(tr('Money held', 'জমা টাকা'), money(bs.fold<double>(0, (s, b) => s + S.bal(b['id'])))), stat(tr('Work value', 'কাজের মূল্য'), money(sum(w, 'amount'))),
              stat(tr('Unpaid', 'বাকি'), money(sum(w, 'amount') - inc), c: kRed), stat(tr('Expenses', 'খরচ'), money(ex)),
              stat(tr('Investment', 'বিনিয়োগ'), money(sum(ofType(a, 'inv'), 'amount'))), stat(tr('Net profit', 'নিট লাভ'), money(inc - ex), c: inc - ex < 0 ? kRed : kGreen)]),
            sec(tr('Daily income', 'দিনভিত্তিক ইনকাম')), card(chart(c, w, 'paid')),
            sec(tr('Monthly summary', 'মাসিক হিসাব')), card(monthly(v)),
            sec(tr('Recent', 'সাম্প্রতিক')), card(v.isEmpty ? Center(child: Text(tr('No records yet', 'এখনো কোনো রেকর্ড নেই'))) : Column(children: [for (final x in (List.of(v)..sort((p, q) => (q['id'] as int).compareTo(p['id'] as int))).take(5)) txRow(c, x)]), p: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
          ],
        ]);
      });
}
void openPage(BuildContext c, String k) {
  final m = <String, Widget>{
    'work': Scaffold(appBar: AppBar(title: Text(tr('Work', 'কাজ'))), body: const TxList(['work'], add: 'work')),
    'exp': Scaffold(appBar: AppBar(title: Text(tr('Expenses', 'খরচ'))), body: const TxList(['exp'], add: 'exp')),
    'inv': Scaffold(appBar: AppBar(title: Text(tr('Investments', 'বিনিয়োগ'))), body: const TxList(['inv'], add: 'inv')),
    'xfer': Scaffold(appBar: AppBar(title: Text(tr('Transfers', 'ট্রান্সফার'))), body: const TxList(['xfer'], add: 'xfer')),
    'due': Scaffold(appBar: AppBar(title: Text(tr('Due', 'বাকি'))), body: const TxList(['work'], due: true)),
    'cap': const FundsPage(), 'priv': const PrivPage(), 'biz': const BizPage(), 'mem': const MembersPage(), 'log': const LogPage(), 'set': const SettingsPage(),
    'rep': Scaffold(appBar: AppBar(title: Text(tr('Reports', 'রিপোর্ট'))), body: const ReportsBody()),
  };
  go(c, m[k]!);
}

// ---------- reports ----------
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext c) => live(() => Scaffold(appBar: AppBar(title: Text(tr('Reports', 'রিপোর্ট'))), body: const ReportsBody()));
}
class ReportsBody extends StatelessWidget {
  const ReportsBody({super.key});
  @override
  Widget build(BuildContext c) => live(() {
        final a = S.vis().where((t) => F.ok(t['date'])).toList(), w = ofType(a, 'work').toList(), p = <String, double>{};
        for (final t in w) { p[t['plat'] ?? '—'] = (p[t['plat'] ?? '—'] ?? 0) + (t['paid'] as num); }
        final inc = sum(w, 'paid'), ex = sum(ofType(a, 'exp'), 'amount');
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
          FilterBar(F), const SizedBox(height: 12),
          grid2([stat(tr('Income', 'ইনকাম'), money(inc), c: kGreen), stat(tr('Expenses', 'খরচ'), money(ex), c: kRed), stat(tr('Profit', 'লাভ'), money(inc - ex)), stat(tr('Records', 'রেকর্ড'), '${a.length}')]),
          const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => exportCsv(a), icon: const Icon(Icons.download_rounded), label: Text(tr('Export CSV', 'CSV এক্সপোর্ট'))),
          sec(tr('Daily income', 'দিনভিত্তিক ইনকাম')), card(chart(c, w, 'paid')),
          sec(tr('By month', 'মাস অনুযায়ী')), card(monthly(S.vis())),
          sec(tr('By platform', 'প্ল্যাটফর্ম অনুযায়ী')), card(p.isEmpty ? Center(child: Text(tr('No data yet', 'এখনো কোনো ডেটা নেই'))) : Column(children: [for (final e in p.entries) ListTile(contentPadding: EdgeInsets.zero, title: Text(e.key), trailing: Text(money(e.value), style: const TextStyle(fontWeight: FontWeight.w800)))])),
        ]);
      });
}

// ---------- businesses / members ----------
class BizPage extends StatelessWidget {
  const BizPage({super.key});
  @override
  Widget build(BuildContext c) => live(() => Scaffold(
        appBar: AppBar(title: Text(tr('Businesses', 'ব্যবসা'))),
        floatingActionButton: S.admin ? FloatingActionButton.extended(onPressed: () => openForm(c, 'biz'), icon: const Icon(Icons.add_rounded), label: Text(tr('Add', 'যোগ করুন'))) : null,
        body: S.biz.isEmpty ? Padding(padding: const EdgeInsets.all(16), child: empty(Icons.business_center_rounded, tr('No businesses yet', 'এখনো কোনো ব্যবসা নেই'), ''))
            : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [for (final b in S.biz) Padding(padding: const EdgeInsets.only(bottom: 12), child: card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [logo(b), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(b['name'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), Text(b['desc'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12))])),
                  if (S.admin) IconButton(onPressed: () => openForm(c, 'bizE', pre: Map<String, dynamic>.from(b)), icon: const Icon(Icons.edit_rounded))]),
                const SizedBox(height: 12),
                Row(children: [Expanded(child: stat(tr('Balance', 'ব্যালেন্স'), money(S.bal(b['id'])))), const SizedBox(width: 10), Expanded(child: stat(tr('Work value', 'কাজের মূল্য'), money(sum(ofType(S.tx.where((t) => t['biz'] == b['id']), 'work'), 'amount'))))]),
                for (final m in S.mem.where((m) => m['biz'] == b['id'])) ListTile(contentPadding: EdgeInsets.zero, leading: av(m), title: Text(m['name']), trailing: Text(money(sum(ofType(S.tx.where((t) => t['by'] == m['id']), 'work'), 'paid')), style: const TextStyle(fontWeight: FontWeight.w700))),
              ])))]),
      ));
}
class MembersPage extends StatelessWidget {
  const MembersPage({super.key});
  @override
  Widget build(BuildContext c) => live(() {
        final ms = S.mem.where((m) => m['role'] != 'admin').toList();
        return Scaffold(
          appBar: AppBar(title: Text(tr('Members', 'সদস্য'))),
          floatingActionButton: FloatingActionButton.extended(onPressed: () { if (S.biz.isEmpty) { toast(tr('Create a business first', 'আগে ব্যবসা তৈরি করুন')); return; } openForm(c, 'mem'); }, icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(tr('Add', 'যোগ করুন'))),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(tr('Private ledgers stay hidden, even from admins.', 'প্রাইভেট হিসাব অ্যাডমিনও দেখতে পারে না।'), style: const TextStyle(color: Colors.grey))),
            if (ms.isEmpty) empty(Icons.group_rounded, tr('No members yet', 'এখনো কোনো সদস্য নেই'), '')
            else for (final m in ms) Padding(padding: const EdgeInsets.only(bottom: 10), child: card(ListTile(contentPadding: EdgeInsets.zero, leading: av(m, s: 48), title: Text(m['name'], style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${S.nm(S.biz, m['biz'])} · ${money(sum(ofType(S.tx.where((t) => t['by'] == m['id']), 'work'), 'paid'))}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => go(c, ProfilePage(pid: m['id']))),
                  IconButton(icon: const Icon(Icons.delete_outline_rounded, color: kRed), onPressed: () async { if (await confirm(c, tr('Delete member?', 'সদস্য মুছবেন?'))) { S.mem.removeWhere((x) => x['id'] == m['id']); S.save(); } })])))),
          ]),
        );
      });
}

// ---------- partner funds ----------
Map<String, double> agg(Iterable l) {
  final r = {'lo': 0.0, 'eq': 0.0, 'rp': 0.0};
  for (final t in l) {
    final n = (t['amount'] as num).toDouble();
    if (t['type'] == 'ret') { r['rp'] = r['rp']! + n; } else if (t['mode'] == 'Equity') { r['eq'] = r['eq']! + n; } else { r['lo'] = r['lo']! + n; }
  }
  r['out'] = math.max(r['lo']! - r['rp']!, 0);
  return r;
}
class FundsPage extends StatelessWidget {
  const FundsPage({super.key});
  @override
  Widget build(BuildContext c) => live(() {
        final a = S.tx.where((t) => (t['type'] == 'cap' || t['type'] == 'ret') && (S.admin || t['by'] == S.d['me'])).toList(), tt = agg(a);
        return Scaffold(appBar: AppBar(title: Text(tr('Partner funds', 'পার্টনার ফান্ড'))), body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          Text(tr('Personal money put into the agency, and what is owed back.', 'নিজের পকেটের টাকা এজেন্সিতে দিলে তার হিসাব।'), style: const TextStyle(color: Colors.grey)), const SizedBox(height: 12),
          Row(children: [Expanded(child: FilledButton.icon(onPressed: S.biz.isEmpty ? null : () => openForm(c, 'cap'), icon: const Icon(Icons.add_rounded), label: Text(tr('Add my money', 'নিজের টাকা দিন')))),
            if (S.admin) ...[const SizedBox(width: 8), OutlinedButton(onPressed: S.biz.isEmpty ? null : () => openForm(c, 'ret'), child: Text(tr('Repay', 'ফেরত দিন')))]]),
          const SizedBox(height: 12),
          grid2([stat(tr('Total put in', 'মোট দিয়েছেন'), money(tt['lo']! + tt['eq']!)), stat(tr('Owed back', 'ফেরত পাওনা'), money(tt['out']!), c: tt['out']! > 0 ? kRed : null), stat(tr('Equity', 'ইকুইটি'), money(tt['eq']!))], n: 3, r: 1.5),
          for (final b in S.biz) ...() {
            final l = a.where((t) => t['biz'] == b['id']).toList();
            if (l.isEmpty) return <Widget>[];
            final tb = agg(S.tx.where((t) => t['biz'] == b['id'] && (t['type'] == 'cap' || t['type'] == 'ret'))), ids = <String>{for (final t in l) t['by'] as String};
            return [sec(b['name']), card(Column(children: [for (final id in ids) () {
              final m = S.mem.firstWhere((x) => x['id'] == id, orElse: () => {'name': '—'}), r = agg(l.where((t) => t['by'] == id)), sh = tb['eq']! > 0 ? (r['eq']! / tb['eq']! * 100).round() : 0;
              return ListTile(contentPadding: EdgeInsets.zero, leading: av(m), title: Text(m['name'], style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${tr('Loan', 'লোন')} ${money(r['lo']!)} · ${tr('Repaid', 'ফেরত')} ${money(r['rp']!)}${r['eq']! > 0 ? ' · ${tr('Equity', 'ইকুইটি')} ${money(r['eq']!)} ($sh%)' : ''}'),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(money(r['out']!), style: TextStyle(fontWeight: FontWeight.w800, color: r['out']! > 0 ? kRed : null)), Text(tr('owed', 'পাওনা'), style: const TextStyle(fontSize: 11, color: Colors.grey))]));
            }()]))];
          }(),
          sec(tr('History', 'হিস্ট্রি')),
          card(a.isEmpty ? Center(child: Text(tr('No records yet', 'এখনো কোনো রেকর্ড নেই'))) : Column(children: [for (final x in (List.of(a)..sort((p, q) => (q['id'] as int).compareTo(p['id'] as int)))) txRow(c, x, act: true)]), p: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
        ]));
      });
}

// ---------- private ledger ----------
class PrivPage extends StatelessWidget {
  const PrivPage({super.key});
  @override
  Widget build(BuildContext c) => live(() {
        final all = S.priv.where((p) => p['user'] == S.d['me']).toList(), b = all.where((p) => PF.ok(p['date'])).toList()..sort((x, y) => (y['date'] as String).compareTo(x['date']));
        final i = sum(b.where((p) => p['kind'] == 'income'), 'amount'), e = sum(b.where((p) => p['kind'] == 'expense'), 'amount'), td = sum(all.where((p) => p['kind'] == 'income' && p['date'] == today()), 'amount');
        return Scaffold(appBar: AppBar(title: Text(tr('My private ledger', 'আমার প্রাইভেট হিসাব'))),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => openForm(c, 'pi'), icon: const Icon(Icons.add_rounded), label: Text(tr('Income', 'ইনকাম'))),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
            Row(children: [const Icon(Icons.lock_rounded, size: 16, color: Colors.grey), const SizedBox(width: 6), Expanded(child: Text(tr('Only you can see this. Not even the admin.', 'শুধু আপনি দেখতে পারবেন। অ্যাডমিনও না।'), style: const TextStyle(color: Colors.grey)))]),
            const SizedBox(height: 10), FilterBar(PF, biz: false), const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF4CC3FF)])), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Today’s private income', 'আজকের প্রাইভেট ইনকাম'), style: const TextStyle(color: Colors.white70)), Text(money(td), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800))])),
            const SizedBox(height: 10),
            grid2([stat(tr('Income', 'ইনকাম'), money(i), c: kGreen), stat(tr('Expense', 'খরচ'), money(e), c: kRed), stat(tr('Net', 'নিট'), money(i - e))], n: 3, r: 1.5),
            Padding(padding: const EdgeInsets.only(top: 10), child: OutlinedButton.icon(onPressed: () => openForm(c, 'pe'), icon: const Icon(Icons.remove_rounded), label: Text(tr('Add expense', 'খরচ যোগ করুন')))),
            sec(tr('Daily private income', 'দিনভিত্তিক প্রাইভেট ইনকাম')), card(chart(c, b.where((p) => p['kind'] == 'income'), 'amount')),
            sec(tr('Entries', 'এন্ট্রি')),
            card(b.isEmpty ? Center(child: Text(tr('No private entries yet', 'এখনো কোনো প্রাইভেট এন্ট্রি নেই'))) : Column(children: [for (final p in b) ListTile(contentPadding: EdgeInsets.zero,
              leading: Icon(p['kind'] == 'expense' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: p['kind'] == 'expense' ? kRed : kGreen),
              title: Text((p['note'] ?? '').toString().isEmpty ? p['kind'] : p['note']), subtitle: Text(p['date']),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(money(p['amount']), style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () { S.priv.removeWhere((x) => x['id'] == p['id']); S.save(); })]))])),
          ]));
      });
}

class LogPage extends StatelessWidget {
  const LogPage({super.key});
  @override
  Widget build(BuildContext c) => live(() => Scaffold(appBar: AppBar(title: Text(tr('Activity log', 'অ্যাক্টিভিটি'))), body: ListView(padding: const EdgeInsets.all(16), children: [
        card(S.logs.isEmpty ? Center(child: Text(tr('No activity yet', 'এখনো কোনো অ্যাক্টিভিটি নেই'))) : Column(children: [for (final l in S.logs) ListTile(contentPadding: EdgeInsets.zero, title: Text('${l['u']} · ${l['m']}'), subtitle: Text(l['t']))]))])));
}

// ---------- settings / profile / gate ----------
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SP();
}
class _SP extends State<SettingsPage> {
  final tg = TextEditingController(text: ((S.d['target'] as num) > 0) ? '${S.d['target']}' : '');
  @override
  Widget build(BuildContext c) => live(() => Scaffold(appBar: AppBar(title: Text(tr('Settings', 'সেটিংস'))), body: ListView(padding: const EdgeInsets.all(16), children: [
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Language', 'ভাষা'), style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8),
          SegmentedButton<String>(segments: const [ButtonSegment(value: 'en', label: Text('English')), ButtonSegment(value: 'bn', label: Text('বাংলা'))], selected: {S.d['lang'] as String}, onSelectionChanged: (s) { S.d['lang'] = s.first; S.save(); }),
          const SizedBox(height: 16), Text(tr('Theme', 'থিম'), style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8),
          SegmentedButton<String>(segments: [ButtonSegment(value: 'system', label: Text(tr('Auto', 'অটো'))), ButtonSegment(value: 'light', label: Text(tr('Light', 'লাইট'))), ButtonSegment(value: 'dark', label: Text(tr('Dark', 'ডার্ক')))], selected: {S.d['theme'] as String}, onSelectionChanged: (s) { S.d['theme'] = s.first; S.save(); }),
        ])), const SizedBox(height: 12),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Monthly income target (৳)', 'মাসিক ইনকাম টার্গেট (৳)'), style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8),
          TextField(controller: tg, keyboardType: TextInputType.number), const SizedBox(height: 10),
          FilledButton(onPressed: () { S.d['target'] = double.tryParse(tg.text) ?? 0; S.save(); toast(tr('Saved', 'সেভ হয়েছে')); }, child: Text(tr('Save', 'সেভ')))])), const SizedBox(height: 12),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Backup', 'ব্যাকআপ'), style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4),
          Text(tr('Move your data to another phone.', 'ডেটা অন্য ফোনে নিতে ব্যাকআপ ব্যবহার করুন।'), style: const TextStyle(color: Colors.grey)), const SizedBox(height: 10),
          Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => shareFile('ops-backup-${today()}.json', jsonEncode(S.d)), icon: const Icon(Icons.download_rounded), label: Text(tr('Backup', 'ব্যাকআপ')))), const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () async {
              final r = await FilePicker.platform.pickFiles(withData: true);
              if (r == null || r.files.first.bytes == null) return;
              try { final m = jsonDecode(utf8.decode(r.files.first.bytes!)); if (m['biz'] == null || m['mem'] == null) throw 0; S.d = Map<String, dynamic>.from(m); S.save(); toast(tr('Restored', 'রিস্টোর হয়েছে')); } catch (_) { toast(tr('Invalid backup file', 'ব্যাকআপ ফাইল ঠিক নয়')); }
            }, icon: const Icon(Icons.upload_rounded), label: Text(tr('Restore', 'রিস্টোর'))))])])), const SizedBox(height: 12),
        OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: kRed), onPressed: () async { if (await confirm(c, tr('Delete ALL data permanently?', 'সব ডেটা মুছে ফেলবেন?'))) { S.d = S.fresh(); S.save(); if (c.mounted) Navigator.of(c).popUntil((r) => r.isFirst); } }, child: Text(tr('Delete all data', 'সব ডেটা মুছুন'))),
      ])));
}

class ProfilePage extends StatefulWidget {
  final String? pid; final bool own;
  const ProfilePage({this.pid, this.own = false, super.key});
  @override
  State<ProfilePage> createState() => _PP();
}
class _PP extends State<ProfilePage> {
  final n = TextEditingController(), e = TextEditingController(), p0 = TextEditingController(), p1 = TextEditingController();
  String? loaded;
  Map get m => S.mem.firstWhere((x) => x['id'] == (widget.pid ?? S.d['me']), orElse: () => S.me);
  @override
  Widget build(BuildContext c) => live(() {
        final pm = m, own = pm['id'] == S.d['me'], can = own || S.admin;
        if (loaded != pm['id']) { n.text = pm['name']; e.text = pm['email'] ?? ''; loaded = pm['id']; }
        return Scaffold(appBar: AppBar(title: Text(tr('Profile', 'প্রোফাইল'))), body: ListView(padding: const EdgeInsets.all(16), children: [
          card(Column(children: [
            GestureDetector(onTap: !can ? null : () async { final p = await pickPhoto(); if (p != null) { pm['photo'] = p; S.save(); } }, child: Stack(children: [av(pm, s: 96),
              if (can) Positioned(right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle), child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white)))])),
            const SizedBox(height: 12), Text(pm['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('${pm['email'] ?? ''} · ${pm['role'] == 'admin' ? tr('Admin', 'অ্যাডমিন') : S.nm(S.biz, pm['biz'])}', style: const TextStyle(color: Colors.grey)),
          ])),
          if (can) ...[
            sec(tr('Edit profile', 'প্রোফাইল এডিট')),
            card(Column(children: [TextField(controller: n, decoration: InputDecoration(labelText: tr('Name', 'নাম'))), const SizedBox(height: 10), TextField(controller: e, decoration: InputDecoration(labelText: tr('Email', 'ইমেইল'))), const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () { if (n.text.trim().isNotEmpty) pm['name'] = n.text.trim(); pm['email'] = e.text.trim().toLowerCase(); S.save(); toast(tr('Saved', 'সেভ হয়েছে')); }, child: Text(tr('Save', 'সেভ'))))])),
            sec(tr('Change password', 'পাসওয়ার্ড বদলান')),
            card(Column(children: [if (own) ...[TextField(controller: p0, obscureText: true, decoration: InputDecoration(labelText: tr('Current password', 'বর্তমান পাসওয়ার্ড'))), const SizedBox(height: 10)],
              TextField(controller: p1, obscureText: true, decoration: InputDecoration(labelText: tr('New password', 'নতুন পাসওয়ার্ড'))), const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () {
                if (p1.text.length < 4) { toast(tr('Min 4 characters', 'কমপক্ষে ৪ অক্ষর')); return; }
                if (own && hash(p0.text) != pm['pw']) { toast(tr('Wrong current password', 'বর্তমান পাসওয়ার্ড ভুল')); return; }
                pm['pw'] = hash(p1.text); S.save(); p0.clear(); p1.clear(); toast(tr('Password updated', 'পাসওয়ার্ড আপডেট হয়েছে'));
              }, child: Text(tr('Update password', 'পাসওয়ার্ড আপডেট'))))])),
          ],
          if (own && widget.pid == null) ...[const SizedBox(height: 16), OutlinedButton.icon(onPressed: () { S.d['in'] = false; S.save(); }, icon: const Icon(Icons.logout_rounded), label: Text(tr('Log out', 'লগ আউট')))],
        ]));
      });
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GT();
}
class _GT extends State<Gate> {
  final n = TextEditingController(), e = TextEditingController(), p = TextEditingController();
  @override
  Widget build(BuildContext c) {
    final setup = S.mem[0]['pw'] == null;
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(children: [
      Container(width: 72, height: 72, decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [kBlue, kSky])), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 36)),
      const SizedBox(height: 16), Text('Private Ops', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      Text(setup ? tr('Create admin account', 'অ্যাডমিন অ্যাকাউন্ট তৈরি') : tr('Welcome back', 'স্বাগতম'), style: const TextStyle(color: Colors.grey)), const SizedBox(height: 24),
      if (setup) ...[TextField(controller: n, decoration: InputDecoration(labelText: tr('Name', 'নাম'))), const SizedBox(height: 12)],
      TextField(controller: e, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: tr('Email', 'ইমেইল'))), const SizedBox(height: 12),
      TextField(controller: p, obscureText: true, decoration: InputDecoration(labelText: tr('Password', 'পাসওয়ার্ড'))), const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () {
        final em = e.text.trim().toLowerCase();
        if (setup) {
          if (em.isEmpty || p.text.length < 4) { toast(tr('Enter email and password (min 4)', 'ইমেইল ও পাসওয়ার্ড দিন (কমপক্ষে ৪)')); return; }
          final a = S.mem[0]; if (n.text.trim().isNotEmpty) a['name'] = n.text.trim(); a['email'] = em; a['pw'] = hash(p.text); S.d['me'] = a['id']; S.d['in'] = true; S.save();
        } else {
          final m = S.mem.where((x) => x['email'] == em && x['pw'] == hash(p.text));
          if (m.isEmpty) { toast(tr('Wrong email or password', 'ইমেইল বা পাসওয়ার্ড ভুল')); return; }
          S.d['me'] = m.first['id']; S.d['in'] = true; S.save();
        }
      }, child: Text(setup ? tr('Create', 'তৈরি করুন') : tr('Log in', 'লগ ইন')))),
      TextButton(onPressed: () { S.d['lang'] = S.bn ? 'en' : 'bn'; S.save(); }, child: Text(S.bn ? 'English' : 'বাংলা')),
    ])))));
  }
}

// ---------- forms ----------
class Fd { final String k, en, bn, ty; final List<List<String>>? o; Fd(this.k, this.en, this.bn, this.ty, [this.o]); }
List<List<String>> bo() => [for (final b in S.biz) [b['id'] as String, b['name'] as String]];
List<List<String>> mo() => [for (final m in S.mem) [m['id'] as String, m['name'] as String]];
List<List<String>> mo2() => S.admin ? mo() : [[S.me['id'] as String, S.me['name'] as String]];
Map<String, dynamic> spec(String k) {
  final b = Fd('biz', 'Business', 'ব্যবসা', 's', bo()), amt = Fd('amount', 'Amount (৳)', 'পরিমাণ (৳)', 'n'), note = Fd('note', 'Note', 'নোট', 'a'), date = Fd('date', 'Date', 'তারিখ', 'd');
  switch (k) {
    case 'work': return {'t': ['Add work', 'কাজ যোগ করুন'], 'f': [b, Fd('plat', 'Platform', 'প্ল্যাটফর্ম', 'c', [for (final p in ['Facebook', 'Instagram', 'TikTok', 'YouTube', 'Other']) [p, p]]), Fd('cat', 'Work category', 'কাজের ধরন', 't'), Fd('amount', 'Work value (৳)', 'কাজের মূল্য (৳)', 'n'), Fd('paid', 'Payment received (৳)', 'পাওয়া টাকা (৳)', 'n'), Fd('note', 'Client details', 'ক্লায়েন্টের তথ্য', 'a'), date]};
    case 'inv': return {'t': ['Add investment', 'বিনিয়োগ যোগ করুন'], 'f': [b, Fd('src', 'Funding source', 'টাকার উৎস', 'c', [['Business balance', tr('Business balance', 'ব্যবসার ব্যালেন্স')], ['My pocket', tr('My pocket', 'নিজের পকেট')]]), Fd('cat', 'What is it for?', 'কিসের জন্য?', 't'), Fd('to', 'Sent to', 'কাকে দেওয়া হলো', 't'), amt, note, date]};
    case 'exp': return {'t': ['Add expense', 'খরচ যোগ করুন'], 'f': [b, Fd('cat', 'Category', 'ক্যাটাগরি', 't'), amt, note, date]};
    case 'xfer': return {'t': ['Record transfer', 'ট্রান্সফার'], 'f': [b, Fd('to', 'Recipient', 'প্রাপক', 's', mo()), amt, note, date]};
    case 'cap': return {'t': ['Add my money to business', 'নিজের টাকা ব্যবসায় দিন'], 'f': [b, Fd('by', 'Who put the money', 'কে টাকা দিয়েছেন', 's', mo2()), Fd('mode', 'Type', 'ধরন', 'c', [['Loan', tr('Loan (repay later)', 'লোন (পরে ফেরত)')], ['Equity', tr('Equity (share)', 'ইকুইটি (শেয়ার)')]]), amt, note, date]};
    case 'ret': return {'t': ['Repay partner', 'পার্টনারকে ফেরত'], 'f': [b, Fd('by', 'Paid back to', 'কাকে ফেরত', 's', mo()), amt, note, date]};
    case 'pay': return {'t': ['Collect payment', 'টাকা নিন'], 'f': [Fd('amount', 'Amount received (৳)', 'পাওয়া টাকা (৳)', 'n')]};
    case 'biz': case 'bizE': return {'t': [k == 'biz' ? 'Add business' : 'Edit business', k == 'biz' ? 'ব্যবসা যোগ করুন' : 'ব্যবসা এডিট'], 'f': [Fd('name', 'Business name', 'ব্যবসার নাম', 't'), Fd('desc', 'Description', 'বিবরণ', 'a'), Fd('logo', 'Logo / picture', 'লোগো / ছবি', 'p')]};
    case 'mem': return {'t': ['Add member', 'সদস্য যোগ করুন'], 'f': [Fd('name', 'Full name', 'পুরো নাম', 't'), Fd('email', 'Email (login)', 'ইমেইল (লগইন)', 't'), Fd('pw', 'Password', 'পাসওয়ার্ড', 'w'), b, Fd('photo', 'Profile photo', 'প্রোফাইল ছবি', 'p')]};
    default: return {'t': [k == 'pi' ? 'Private income' : 'Private expense', k == 'pi' ? 'প্রাইভেট ইনকাম' : 'প্রাইভেট খরচ'], 'f': [amt, note, date]};
  }
}
void openForm(BuildContext c, String kind, {Map<String, dynamic>? pre}) {
  final p = Map<String, dynamic>.from(pre ?? {});
  if ((kind == 'cap') && p['by'] == null) p['by'] = S.d['me'];
  showModalBottomSheet(context: c, isScrollControlled: true, useSafeArea: true, builder: (_) => FormSheet(kind, p));
}
class FormSheet extends StatefulWidget {
  final String kind; final Map<String, dynamic> pre;
  const FormSheet(this.kind, this.pre, {super.key});
  @override
  State<FormSheet> createState() => _FS();
}
class _FS extends State<FormSheet> {
  late Map<String, dynamic> v; final ctl = <String, TextEditingController>{}; late List<Fd> fs; late List title;
  @override
  void initState() {
    super.initState();
    final s = spec(widget.kind);
    fs = (s['f'] as List).cast<Fd>(); title = s['t'];
    v = {'date': today(), ...widget.pre};
    for (final f in fs) {
      if ((f.ty == 's' || f.ty == 'c') && (v[f.k] == null || !f.o!.any((x) => x[0] == v[f.k]))) { if (f.o!.isNotEmpty) v[f.k] = f.o![0][0]; }
      if (f.ty == 't' || f.ty == 'n' || f.ty == 'w' || f.ty == 'a') ctl[f.k] = TextEditingController(text: v[f.k] == null ? '' : '${v[f.k]}');
    }
  }
  void save() {
    final k = widget.kind;
    for (final e in ctl.entries) { v[e.key] = e.value.text.trim(); }
    final amt = double.tryParse('${v['amount'] ?? ''}') ?? 0;
    if (['work', 'inv', 'exp', 'xfer', 'pi', 'pe', 'pay', 'cap', 'ret'].contains(k) && amt <= 0) { toast(tr('Please enter an amount', 'পরিমাণ লিখুন')); return; }
    if (['biz', 'bizE', 'mem'].contains(k) && '${v['name'] ?? ''}'.isEmpty) { toast(tr('Name required', 'নাম দিন')); return; }
    final id = S.d['n'] as int;
    if (k == 'pay') {
      final t = S.tx.firstWhere((x) => x['id'] == v['pid']);
      t['paid'] = math.min((t['amount'] as num).toDouble(), (t['paid'] as num) + amt); S.log('collected payment');
    } else if (k == 'bizE') {
      final b = S.biz.firstWhere((x) => x['id'] == v['id']); b['name'] = v['name']; b['desc'] = v['desc'] ?? ''; b['logo'] = v['logo'];
    } else if (k == 'biz') {
      S.biz.add({'id': 'b$id', 'name': v['name'], 'desc': v['desc'] ?? '', 'logo': v['logo']}); S.d['n'] = id + 1;
    } else if (k == 'mem') {
      if ('${v['email'] ?? ''}'.isEmpty || '${v['pw'] ?? ''}'.isEmpty) { toast(tr('Email and password required', 'ইমেইল ও পাসওয়ার্ড দিন')); return; }
      S.mem.add({'id': 'u$id', 'name': v['name'], 'role': 'member', 'biz': v['biz'], 'email': '${v['email']}'.toLowerCase(), 'pw': hash(v['pw']), 'photo': v['photo']}); S.d['n'] = id + 1;
    } else if (k == 'pi' || k == 'pe') {
      S.priv.add({'id': id, 'user': S.d['me'], 'kind': k == 'pi' ? 'income' : 'expense', 'amount': amt, 'note': v['note'] ?? '', 'date': v['date']}); S.d['n'] = id + 1;
    } else {
      final paid = k == 'work' ? ('${v['paid'] ?? ''}'.isEmpty ? amt : (double.tryParse('${v['paid']}') ?? amt)) : 0;
      S.tx.add({'id': id, 'type': k, 'biz': v['biz'], 'by': v['by'] ?? S.d['me'], 'date': v['date'], 'cat': v['cat'] ?? '', 'plat': v['plat'], 'amount': amt, 'paid': paid, 'note': v['note'] ?? '', 'to': v['to'], 'src': v['src'], 'mode': v['mode']});
      S.d['n'] = id + 1; S.log('added ${(title[0] as String).toLowerCase()}');
    }
    S.save();
    Navigator.pop(context);
  }
  Widget field(Fd f) {
    final label = tr(f.en, f.bn);
    switch (f.ty) {
      case 's': return DropdownButtonFormField<String>(value: v[f.k] as String?, isExpanded: true, decoration: InputDecoration(labelText: label), items: [for (final o in f.o!) DropdownMenuItem(value: o[0], child: Text(o[1]))], onChanged: (x) => setState(() => v[f.k] = x));
      case 'c': return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 6), Wrap(spacing: 8, children: [for (final o in f.o!) ChoiceChip(label: Text(o[1]), selected: v[f.k] == o[0], onSelected: (_) => setState(() => v[f.k] = o[0]))])]);
      case 'd': return InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(v[f.k]) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setState(() => v[f.k] = ymd(d)); },
          child: InputDecorator(decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18)), child: Text(v[f.k])));
      case 'p': return Row(children: [pic(v[f.k] as String?, 64, const Icon(Icons.image_rounded, color: kBlue)), const SizedBox(width: 12),
          OutlinedButton.icon(onPressed: () async { final p = await pickPhoto(); if (p != null) setState(() => v[f.k] = p); }, icon: const Icon(Icons.camera_alt_rounded), label: Text(tr('Choose photo', 'ছবি বাছুন')))]);
      default: return TextField(controller: ctl[f.k], obscureText: f.ty == 'w', maxLines: f.ty == 'a' ? 3 : 1, keyboardType: f.ty == 'n' ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: label));
    }
  }
  @override
  Widget build(BuildContext c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(tr(title[0], title[1]), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close_rounded))]),
          if (widget.kind == 'cap') Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('Loan = owed back to you. Equity = your share of the business.', 'লোন = পরে আপনি ফেরত পাবেন। ইকুইটি = ব্যবসায় আপনার শেয়ার।'), style: const TextStyle(fontSize: 12, color: Colors.grey))),
          for (final f in fs) Padding(padding: const EdgeInsets.only(top: 14), child: field(f)),
          const SizedBox(height: 22), SizedBox(width: double.infinity, child: FilledButton(onPressed: save, child: Text(tr('Save', 'সেভ')))),
        ])),
      );
}
