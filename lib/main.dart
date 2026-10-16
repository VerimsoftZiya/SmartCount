import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const teal = Color(0xFF00A6A6);
const tealDark = Color(0xFF006D6D);

void main() => runApp(MaterialApp(
      title: 'Sayım',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: teal, primary: teal),
          appBarTheme: const AppBarTheme(backgroundColor: teal, foregroundColor: Colors.white),
          useMaterial3: true),
      home: const Home(),
    ));

// ---------- Ortak veri ----------
class V {
  String code, name, color, size;
  List<String> a; // Ozellik1Kod, Ozellik1Ad ... Ozellik4Ad
  List<String> bc = [];
  V(this.code, this.name, this.color, this.size, this.a);
}

class L {
  String bc, dep, loc;
  int q;
  bool undef;
  L(this.bc, this.dep, this.loc, this.q, this.undef);
  Map toJson() => {'bc': bc, 'dep': dep, 'loc': loc, 'q': q, 'u': undef};
  factory L.fromJson(Map j) => L(j['bc'], j['dep'], j['loc'], j['q'], j['u']);
}

final Map<String, V> byBarcode = {};
String device = '', user = '';
late SharedPreferences prefs;

Future<String> ask(BuildContext context, String title, String hint) async {
  final c = TextEditingController();
  String r = '';
  while (r.isEmpty) {
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
              title: Text(title),
              content: TextField(controller: c, autofocus: true, decoration: InputDecoration(hintText: hint)),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
            ));
    r = c.text.trim();
  }
  return r;
}

Future<File> dataFile() async => File('${(await getApplicationDocumentsDirectory()).path}/urun_verisi.csv');

// CSV kolonları: UrunKodu,UrunAdi,Renk,Beden,Ozellik1Kod,Ozellik1Ad,...,Ozellik4Ad,Barkod
void parse(String txt) {
  byBarcode.clear();
  txt = txt.replaceAll('\uFEFF', '');
  final d = txt.split('\n').first.contains(';') ? ';' : ',';
  final rows = const CsvToListConverter(shouldParseNumbers: false).convert(txt, fieldDelimiter: d, eol: '\n');
  final variants = <String, V>{};
  for (final r in rows.skip(1)) {
    if (r.length < 13) continue;
    final s = r.map((e) => e.toString().trim()).toList();
    final v = variants.putIfAbsent('${s[0]}|${s[2]}|${s[3]}', () => V(s[0], s[1], s[2], s[3], s.sublist(4, 12)));
    if (s[12].isNotEmpty) {
      v.bc.add(s[12]);
      byBarcode[s[12]] = v;
    }
  }
}

List<L> loadLines() {
  final s = prefs.getString('lines');
  return s == null ? [] : (jsonDecode(s) as List).map((e) => L.fromJson(e)).toList();
}

// ---------- Ana ekran ----------
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => boot());
  }

  Future<void> boot() async {
    prefs = await SharedPreferences.getInstance();
    device = prefs.getString('device') ?? '';
    if (device.isEmpty) {
      device = await ask(context, 'Cihaz Adı', 'Bu ad sonradan DEĞİŞTİRİLEMEZ.');
      await prefs.setString('device', device);
    }
    user = await ask(context, 'Kullanıcı Adı', 'Giriş yapan kullanıcı');
    final f = await dataFile();
    if (await f.exists()) parse(utf8.decode(await f.readAsBytes(), allowMalformed: true));
    setState(() => ready = true);
  }

  void snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> importData() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
    if (r?.files.single.path == null) return;
    final bytes = await File(r!.files.single.path!).readAsBytes();
    await (await dataFile()).writeAsBytes(bytes);
    parse(utf8.decode(bytes, allowMalformed: true));
    setState(() {});
    snack('${byBarcode.length} barkod yüklendi');
  }

  Future<void> openCount() async {
    if (byBarcode.isEmpty) return snack('Önce ürün verisini yükleyin');
    final r = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const CountPage()));
    setState(() {});
    if (r != null) snack(r.isEmpty ? 'Excel kaydedilemedi!' : 'Excel kaydedildi: $r');
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final open = loadLines();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [tealDark, teal, Color(0xFF7FDCDC)])),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 24),
              const Icon(Icons.qr_code_scanner, size: 72, color: Colors.white),
              const SizedBox(height: 8),
              const Text('Barkodlu Sayım', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Kullanıcı: $user   •   Cihaz: $device', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              SizedBox(
                height: 80,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: tealDark),
                  onPressed: openCount,
                  icon: const Icon(Icons.fact_check, size: 32),
                  label: Text(open.isEmpty ? 'SAYIM' : 'SAYIM (devam: ${open.length} satır)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                  onPressed: importData,
                  icon: const Icon(Icons.upload_file),
                  label: Text('Veri Yükle  (${byBarcode.length} barkod)'),
                ),
              ),
              const Spacer(),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------- Sayım ekranı ----------
class CountPage extends StatefulWidget {
  const CountPage({super.key});
  @override
  State<CountPage> createState() => _CountPageState();
}

class _CountPageState extends State<CountPage> {
  List<L> lines = [];
  String dep = '0701', loc = '';
  bool add = true;
  final scanC = TextEditingController(), locC = TextEditingController();
  final scanF = FocusNode(), locF = FocusNode();
  final depots = List.generate(21, (i) => '07${(i + 1).toString().padLeft(2, '0')}');

  @override
  void initState() {
    super.initState();
    lines = loadLines(); // kaldığı yerden devam
    dep = prefs.getString('dep') ?? '0701';
    loc = prefs.getString('loc') ?? '';
    locC.text = loc;
    WidgetsBinding.instance.addPostFrameCallback((_) => scanF.requestFocus());
  }

  void snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> save() async {
    await prefs.setString('lines', jsonEncode(lines.map((e) => e.toJson()).toList()));
    await prefs.setString('dep', dep);
    await prefs.setString('loc', loc);
  }

  void setLoc(String v) {
    loc = v.trim();
    locC.text = loc;
    scanF.requestFocus();
    save();
    setState(() {});
  }

  Future<void> scan(String raw) async {
    final bc = raw.trim();
    scanC.clear();
    scanF.requestFocus();
    if (bc.isEmpty) return;
    if (loc.isEmpty) return setLoc(bc); // lokasyon boşsa okutulan barkod lokasyondur
    final i = lines.indexWhere((l) => l.bc == bc && l.dep == dep && l.loc == loc);
    if (i < 0) {
      if (!add) return snack('Bu barkod için satır yok');
      final l = L(bc, dep, loc, 1, !byBarcode.containsKey(bc));
      lines.insert(0, l);
      await save();
      setState(() {});
      if (l.undef) {
        await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
                  title: const Text('Uyarı'),
                  content: Text('Tanımsız barkod okuttunuz:\n$bc'),
                  actions: [
                    TextButton(
                        onPressed: () {
                          lines.remove(l);
                          Navigator.pop(context);
                        },
                        child: const Text('Çıkar')),
                    FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Devam')),
                  ],
                ));
      }
    } else {
      final n = lines[i].q + (add ? 1 : -1);
      if (n < 0) return snack('Miktar 0\'ın altına inemez');
      lines[i].q = n;
    }
    HapticFeedback.lightImpact();
    await save();
    setState(() {});
    scanF.requestFocus();
  }

  Future<void> editQty(L l) async {
    final c = TextEditingController(text: '${l.q}');
    await showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(l.bc),
              content: TextField(controller: c, keyboardType: TextInputType.number, autofocus: true),
              actions: [
                TextButton(
                    onPressed: () {
                      lines.remove(l);
                      Navigator.pop(context);
                    },
                    child: const Text('Satırı Sil')),
                FilledButton(
                    onPressed: () {
                      l.q = (int.tryParse(c.text) ?? l.q).clamp(0, 999999);
                      Navigator.pop(context);
                    },
                    child: const Text('Kaydet')),
              ],
            ));
    await save();
    setState(() {});
    scanF.requestFocus();
  }

  Future<void> finish() async {
    if (lines.isEmpty) return snack('Sayım boş');
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Sayımı kaydet?'),
              content: const Text('Excel oluşturulacak, sayım temizlenecek ve ana ekrana dönülecek.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaydet')),
              ],
            ));
    if (ok != true) return;
    final path = await exportExcel();
    if (path.isEmpty) return snack('Excel yazılamadı, sayım silinmedi!');
    lines.clear();
    loc = '';
    await save();
    if (mounted) Navigator.pop(context, path);
  }

  Future<String> exportExcel() async {
    final x = Excel.createExcel();
    x.rename('Sheet1', 'Sayim');
    final sh = x['Sayim'];
    sh.appendRow(([
      'Ürün Kodu', 'Ürün Adı', 'Renk', 'Beden',
      'Özellik 1 Kodu', 'Özellik 1 Adı', 'Özellik 2 Kodu', 'Özellik 2 Adı',
      'Özellik 3 Kodu', 'Özellik 3 Adı', 'Özellik 4 Kodu', 'Özellik 4 Adı',
      'Barkod 1', 'Barkod 2', 'Barkod 3', 'Miktar', 'Lokasyon', 'Depo', 'Kullanıcı Adı', 'Cihaz Adı'
    ]).map((e) => TextCellValue(e)).toList());
    final agg = <String, List>{};
    final undef = <L>[];
    for (final l in lines) {
      final v = byBarcode[l.bc];
      if (l.undef || v == null) {
        undef.add(l);
        continue;
      }
      final k = '${v.code}|${v.color}|${v.size}|${l.dep}|${l.loc}';
      agg.putIfAbsent(k, () => [v, l.dep, l.loc, 0])[3] += l.q;
    }
    CellValue cv(c) => c is int ? IntCellValue(c) : TextCellValue('$c');
    for (final e in agg.values) {
      final V v = e[0];
      final b = [...v.bc, '', '', ''].sublist(0, 3);
      sh.appendRow([v.code, v.name, v.color, v.size, ...v.a, ...b, e[3], e[2], e[1], user, device].map(cv).toList());
    }
    final red = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#FFC7CE'), fontColorHex: ExcelColor.fromHexString('#9C0006'));
    for (final l in undef) {
      sh.appendRow(['', '', '', '', '', '', '', '', '', '', '', '', l.bc, '', '', l.q, l.loc, l.dep, user, device].map(cv).toList());
      for (var c = 0; c < 20; c++) {
        sh.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: sh.maxRows - 1)).cellStyle = red;
      }
    }
    final n = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    final name = 'Sayim_${dep}_${n.year}${p(n.month)}${p(n.day)}_${p(n.hour)}${p(n.minute)}${p(n.second)}.xlsx';
    final bytes = x.encode()!;
    for (final dir in ['/storage/emulated/0/Download', (await getExternalStorageDirectory())?.path, (await getApplicationDocumentsDirectory()).path]) {
      if (dir == null) continue;
      try {
        final f = File('$dir/$name');
        await f.writeAsBytes(bytes);
        return f.path;
      } catch (_) {}
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sayım  •  $user', style: const TextStyle(fontSize: 16)),
        actions: [TextButton.icon(onPressed: finish, icon: const Icon(Icons.save, color: Colors.white), label: const Text('KAYDET', style: TextStyle(color: Colors.white)))],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: dep,
              decoration: const InputDecoration(labelText: 'Depo Kodu', border: OutlineInputBorder(), isDense: true),
              items: depots.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                setState(() => dep = v!);
                save();
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: locC,
              focusNode: locF,
              keyboardType: TextInputType.none,
              decoration: InputDecoration(
                  labelText: 'Lokasyon (boşken okutulan ilk barkod)',
                  prefixIcon: const Icon(Icons.place),
                  suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        loc = '';
                        locC.clear();
                        scanF.requestFocus();
                        save();
                        setState(() {});
                      }),
                  border: const OutlineInputBorder(),
                  isDense: true),
              onSubmitted: setLoc,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('EKLE'), icon: Icon(Icons.add)),
                  ButtonSegment(value: false, label: Text('ÇIKAR'), icon: Icon(Icons.remove)),
                ],
                selected: {add},
                onSelectionChanged: (s) {
                  setState(() => add = s.first);
                  scanF.requestFocus();
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: scanC,
              focusNode: scanF,
              keyboardType: TextInputType.none,
              decoration: const InputDecoration(
                  labelText: 'Ürün barkodu okutun', prefixIcon: Icon(Icons.qr_code_scanner), border: OutlineInputBorder(), isDense: true),
              onSubmitted: scan,
            ),
          ]),
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          color: teal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: const Row(children: [
            Expanded(flex: 3, child: Text('Barkod', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Expanded(flex: 4, child: Text('Ürün Adı', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Text('Miktar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: lines.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final l = lines[i];
              final v = byBarcode[l.bc];
              final c = l.undef ? Colors.red.shade900 : Colors.black87;
              return InkWell(
                onTap: () => editQty(l),
                child: Container(
                  color: l.undef ? const Color(0xFFFFC7CE) : (i.isEven ? const Color(0xFFE6F7F7) : Colors.white),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text(l.bc, style: TextStyle(color: c, fontSize: 13))),
                    Expanded(
                        flex: 4,
                        child: Text(v == null ? 'TANIMSIZ' : '${v.name} ${v.color} ${v.size}',
                            style: TextStyle(color: c, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    SizedBox(width: 48, child: Text('${l.q}', textAlign: TextAlign.right, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 16))),
                  ]),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Text('Toplam: ${lines.fold<int>(0, (s, l) => s + l.q)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(onPressed: finish, icon: const Icon(Icons.save), label: const Text('Kaydet')),
            ]),
          ),
        ),
      ]),
    );
  }
}
