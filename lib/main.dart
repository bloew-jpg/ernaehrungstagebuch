import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'datei_auswahl_optionen.dart'
    if (dart.library.js_interop) 'datei_auswahl_optionen_web.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ErnaehrungsApp());
}

const Color _hintergrund = Color(0xFFFAF8F4);
const Color _navy = Color(0xFF183047);
const Color _grauBlau = Color(0xFF7A8794);
const Color _terrakotta = Color(0xFFC95836);
const Color _terrakottaHell = Color(0xFFFBEAE3);
const Color _blau = Color(0xFF5B8DB3);
const Color _blauHell = Color(0xFFE6EFF6);
const Color _ocker = Color(0xFFD89A3D);
const Color _ockerHell = Color(0xFFFAF0DC);
const Color _cremeKreis = Color(0xFFF1ECE3);

class ErnaehrungsApp extends StatelessWidget {
  const ErnaehrungsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mein Ernährungstagebuch',
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: _terrakotta,
              surface: _hintergrund,
            ).copyWith(
              primary: _terrakotta,
              onPrimary: Colors.white,
              onSurface: _navy,
              onSurfaceVariant: _grauBlau,
              surfaceTint: Colors.transparent,
              surfaceContainerHighest: _cremeKreis,
            ),
        scaffoldBackgroundColor: _hintergrund,
        appBarTheme: const AppBarTheme(
          backgroundColor: _hintergrund,
          foregroundColor: _navy,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        useMaterial3: true,
      ),
      home: const TagesSeite(),
    );
  }
}

class TagesSeite extends StatefulWidget {
  const TagesSeite({super.key});

  @override
  State<TagesSeite> createState() => _TagesSeiteState();
}

class _TagesSeiteState extends State<TagesSeite> {
  DateTime ausgewaehlterTag = DateTime.now();

  final Map<String, String> notizenNachTag = {};
  final TextEditingController notizController = TextEditingController();
  Timer? _notizTimer;
  late final Future<void> _notizenGeladen;

  @override
  void initState() {
    super.initState();
    _datenLaden();
    _mahlzeitenLaden();
    _notizenGeladen = _notizenLaden();
  }

  @override
  void dispose() {
    if (_notizTimer?.isActive ?? false) {
      _notizSofortSpeichern();
    }
    _notizTimer?.cancel();
    notizController.dispose();
    super.dispose();
  }

  Future<void> _notizenLaden() async {
    final prefs = await SharedPreferences.getInstance();
    final gespeicherteDaten = prefs.getString('tagesnotizen');

    if (gespeicherteDaten == null) return;

    final decoded = jsonDecode(gespeicherteDaten) as Map<String, dynamic>;

    if (!mounted) return;

    // Bereits während des Ladens getippte Notizen haben Vorrang.
    decoded.forEach((tag, text) {
      notizenNachTag.putIfAbsent(tag, () => text as String);
    });

    final aktuellerText = notizenNachTag[_tagSchluessel(ausgewaehlterTag)];
    if (notizController.text.isEmpty && aktuellerText != null) {
      notizController.text = aktuellerText;
    }
  }

  Future<void> _notizenSpeichern() async {
    await _notizenGeladen;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('tagesnotizen', jsonEncode(notizenNachTag));
  }

  void _notizAnwenden() {
    final schluessel = _tagSchluessel(ausgewaehlterTag);

    if (notizController.text.trim().isEmpty) {
      notizenNachTag.remove(schluessel);
    } else {
      notizenNachTag[schluessel] = notizController.text;
    }
  }

  void _notizGeaendert(String _) {
    _notizAnwenden();
    _notizTimer?.cancel();
    _notizTimer = Timer(const Duration(milliseconds: 500), _notizenSpeichern);
  }

  // Muss vor jedem Tageswechsel laufen, solange ausgewaehlterTag noch der
  // Tag der angezeigten Notiz ist.
  void _notizSofortSpeichern() {
    if (!(_notizTimer?.isActive ?? false)) return;

    _notizTimer!.cancel();
    _notizAnwenden();
    _notizenSpeichern();
  }

  void _notizAnzeigen() {
    notizController.text =
        notizenNachTag[_tagSchluessel(ausgewaehlterTag)] ?? '';
  }

  Future<void> _datenLaden() async {
    final prefs = await SharedPreferences.getInstance();
    final gespeicherteDaten = prefs.getString('trinkEintraege');

    if (gespeicherteDaten == null) return;

    final decoded = jsonDecode(gespeicherteDaten) as Map<String, dynamic>;

    final geladeneDaten = <String, List<TrinkEintrag>>{};

    decoded.forEach((tag, eintraege) {
      geladeneDaten[tag] = (eintraege as List)
          .map(
            (eintrag) => TrinkEintrag(
              mengeMl: eintrag['mengeMl'] as int,
              uhrzeit: DateTime.parse(eintrag['uhrzeit'] as String),
              getraenk: eintrag['getraenk'] as String?,
            ),
          )
          .toList();
    });

    if (!mounted) return;

    setState(() {
      trinkEintraegeNachTag
        ..clear()
        ..addAll(geladeneDaten);
    });
  }

  Future<void> _datenSpeichern() async {
    final prefs = await SharedPreferences.getInstance();

    final daten = trinkEintraegeNachTag.map(
      (tag, eintraege) => MapEntry(
        tag,
        eintraege
            .map(
              (eintrag) => {
                'mengeMl': eintrag.mengeMl,
                'uhrzeit': eintrag.uhrzeit.toIso8601String(),
                if (eintrag.getraenk != null) 'getraenk': eintrag.getraenk,
              },
            )
            .toList(),
      ),
    );

    await prefs.setString('trinkEintraege', jsonEncode(daten));
  }

  final Map<String, List<TrinkEintrag>> trinkEintraegeNachTag = {};
  final Map<String, List<MahlzeitEintrag>> mahlzeitenNachTag = {};

  List<MahlzeitEintrag> get mahlzeiten {
    final liste = mahlzeitenNachTag[_tagSchluessel(ausgewaehlterTag)] ?? [];

    return [...liste]..sort(
      (a, b) => a.minutenSeitMitternacht.compareTo(b.minutenSeitMitternacht),
    );
  }

  Future<void> _mahlzeitenLaden() async {
    final prefs = await SharedPreferences.getInstance();
    final gespeicherteDaten = prefs.getString('mahlzeiten');

    if (gespeicherteDaten == null) return;

    final decoded = jsonDecode(gespeicherteDaten) as Map<String, dynamic>;
    final geladeneDaten = decoded.map(
      (tag, eintraege) => MapEntry(
        tag,
        (eintraege as List)
            .map((e) => MahlzeitEintrag.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );

    if (!mounted) return;

    setState(() {
      mahlzeitenNachTag
        ..clear()
        ..addAll(geladeneDaten);
    });
  }

  Future<void> _mahlzeitenSpeichern() async {
    final prefs = await SharedPreferences.getInstance();

    final daten = mahlzeitenNachTag.map(
      (tag, eintraege) =>
          MapEntry(tag, eintraege.map((e) => e.toJson()).toList()),
    );

    await prefs.setString('mahlzeiten', jsonEncode(daten));
  }

  static const int trinkZielMl = 3000;

  bool trinkDetailsOffen = false;

  String _tagSchluessel(DateTime datum) {
    final jahr = datum.year.toString().padLeft(4, '0');
    final monat = datum.month.toString().padLeft(2, '0');
    final tag = datum.day.toString().padLeft(2, '0');

    return '$jahr-$monat-$tag';
  }

  List<TrinkEintrag> get trinkEintraege {
    final schluessel = _tagSchluessel(ausgewaehlterTag);

    return trinkEintraegeNachTag.putIfAbsent(schluessel, () => []);
  }

  int get getrunkeneMl {
    return trinkEintraege.fold(0, (summe, eintrag) => summe + eintrag.mengeMl);
  }

  String get trinkMengeText {
    if (getrunkeneMl < 1000) {
      return '$getrunkeneMl ml';
    }

    final liter = getrunkeneMl / 1000;

    return '${liter.toStringAsFixed(2).replaceAll('.', ',')} l';
  }

  void _vorherigerTag() {
    _notizSofortSpeichern();
    setState(() {
      ausgewaehlterTag = ausgewaehlterTag.subtract(const Duration(days: 1));
      trinkDetailsOffen = false;
      _notizAnzeigen();
    });
  }

  void _naechsterTag() {
    final heute = DateTime.now();

    final istHeute =
        ausgewaehlterTag.year == heute.year &&
        ausgewaehlterTag.month == heute.month &&
        ausgewaehlterTag.day == heute.day;

    if (!istHeute) {
      _notizSofortSpeichern();
      setState(() {
        ausgewaehlterTag = ausgewaehlterTag.add(const Duration(days: 1));
        trinkDetailsOffen = false;
        _notizAnzeigen();
      });
    }
  }

  static const int _backupVersion = 1;

  void _hinweis(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _datensicherungOeffnen() async {
    final aktion = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Datensicherung'),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Backup erstellen'),
              onTap: () => Navigator.pop(context, 'erstellen'),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('Backup wiederherstellen'),
              onTap: () => Navigator.pop(context, 'wiederherstellen'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );

    if (aktion == 'erstellen') {
      await _backupErstellen();
    } else if (aktion == 'wiederherstellen') {
      await _backupWiederherstellen();
    }
  }

  Future<void> _backupErstellen() async {
    _notizSofortSpeichern();
    _notizAnwenden();

    final jetzt = DateTime.now();
    final daten = {
      'version': _backupVersion,
      'erstelltAm': jetzt.toIso8601String(),
      'trinkEintraegeNachTag': trinkEintraegeNachTag.map(
        (tag, liste) => MapEntry(tag, liste.map((e) => e.toJson()).toList()),
      ),
      'mahlzeitenNachTag': mahlzeitenNachTag.map(
        (tag, liste) => MapEntry(tag, liste.map((e) => e.toJson()).toList()),
      ),
      'notizenNachTag': notizenNachTag,
    };
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(daten)),
    );

    try {
      final ziel = await FilePicker.saveFile(
        fileName: 'ernaehrungstagebuch_backup_${_tagSchluessel(jetzt)}.json',
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: 'Backup speichern',
      );
      if (ziel != null && mounted) _hinweis('Backup wurde erstellt.');
    } catch (e) {
      debugPrint('Backup fehlgeschlagen: $e');
      if (mounted) _hinweis('Backup konnte nicht gespeichert werden.');
    }
  }

  // Liest und validiert das komplette Backup, ohne vorhandene Daten zu ändern.
  ({
    Map<String, List<TrinkEintrag>> trinken,
    Map<String, List<MahlzeitEintrag>> mahlzeiten,
    Map<String, String> notizen,
  })
  _backupParsen(String inhalt) {
    final json = jsonDecode(inhalt);
    if (json is! Map<String, dynamic>) throw const FormatException();
    if (json['version'] != _backupVersion) throw const FormatException();

    final trinken = (json['trinkEintraegeNachTag'] as Map<String, dynamic>).map(
      (tag, liste) => MapEntry(
        tag,
        (liste as List)
            .map((e) => TrinkEintrag.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
    final mahlzeiten = (json['mahlzeitenNachTag'] as Map<String, dynamic>).map(
      (tag, liste) => MapEntry(
        tag,
        (liste as List)
            .map((e) => MahlzeitEintrag.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
    final notizen = (json['notizenNachTag'] as Map<String, dynamic>).map(
      (tag, text) => MapEntry(tag, text as String),
    );

    return (trinken: trinken, mahlzeiten: mahlzeiten, notizen: notizen);
  }

  Future<void> _backupWiederherstellen() async {
    const fehlertext =
        'Diese Datei ist kein gültiges Backup des Ernährungstagebuchs.';

    final String inhalt;
    try {
      final dateien = await FilePicker.pickFiles(
        dialogTitle: 'Backup auswählen',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        webOptions: dateiAuswahlWebOptionen(),
      );
      if (dateien.isEmpty) return;
      final bytes = await dateien.first.readAsBytes();
      inhalt = utf8.decode(bytes);
    } catch (e) {
      debugPrint('Backup lesen fehlgeschlagen: $e');
      if (mounted) _hinweis(fehlertext);
      return;
    }

    final ({
      Map<String, List<TrinkEintrag>> trinken,
      Map<String, List<MahlzeitEintrag>> mahlzeiten,
      Map<String, String> notizen,
    })
    backup;
    try {
      backup = _backupParsen(inhalt);
    } catch (e) {
      debugPrint('Backup ungültig: $e');
      if (mounted) _hinweis(fehlertext);
      return;
    }

    if (!mounted) return;

    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup wiederherstellen?'),
        content: const Text(
          'Die vorhandenen Daten auf diesem Gerät werden durch die Daten '
          'aus dem Backup ersetzt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wiederherstellen'),
          ),
        ],
      ),
    );

    if (bestaetigt != true || !mounted) return;

    _notizTimer?.cancel();
    await _notizenGeladen;

    setState(() {
      trinkEintraegeNachTag
        ..clear()
        ..addAll(backup.trinken);
      mahlzeitenNachTag
        ..clear()
        ..addAll(backup.mahlzeiten);
      notizenNachTag
        ..clear()
        ..addAll(backup.notizen);
      _notizAnzeigen();
    });

    await _datenSpeichern();
    await _mahlzeitenSpeichern();
    await _notizenSpeichern();

    if (mounted) _hinweis('Backup wurde wiederhergestellt.');
  }

  Future<void> _exportOeffnen() async {
    final zeitraum = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      builder: (context) => const _ExportSheet(),
    );

    if (zeitraum == null) return;

    _pdfErstellen(zeitraum.start, zeitraum.end);
  }

  static const _monatsnamen = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];
  static const _wochentagsnamen = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];
  static const _motivNamen = {
    'G': 'Gewohnheit',
    'E': 'Emotionen',
    'F': 'Frust',
    'Ü': 'Gelüste',
    'H': 'Hunger',
    'L': 'Langeweile',
  };

  String _pdfZeitraumText(DateTime start, DateTime ende) {
    if (_tagSchluessel(start) == _tagSchluessel(ende)) {
      return '${start.day}. ${_monatsnamen[start.month - 1]} ${start.year}';
    }
    final startText = start.year == ende.year
        ? '${start.day}. ${_monatsnamen[start.month - 1]}'
        : '${start.day}. ${_monatsnamen[start.month - 1]} ${start.year}';
    return '$startText - ${ende.day}. ${_monatsnamen[ende.month - 1]} '
        '${ende.year}';
  }

  String _zweistellig(int zahl) => zahl.toString().padLeft(2, '0');

  Future<void> _pdfErstellen(DateTime start, DateTime ende) async {
    final dokument = pw.Document(title: 'Ernährungstagebuch');
    const grau = PdfColor.fromInt(0xFF666666);
    const linie = PdfColor.fromInt(0xFFCCCCCC);

    final inhalt = <pw.Widget>[
      pw.Text(
        'Ernährungstagebuch',
        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
      ),
      if (_tagSchluessel(start) != _tagSchluessel(ende)) ...[
        pw.SizedBox(height: 4),
        pw.Text(
          _pdfZeitraumText(start, ende),
          style: const pw.TextStyle(fontSize: 13, color: grau),
        ),
      ],
      pw.SizedBox(height: 16),
    ];
    final kopfLaenge = inhalt.length;

    var tag = DateTime(start.year, start.month, start.day);
    final letzterTag = DateTime(ende.year, ende.month, ende.day);

    while (!tag.isAfter(letzterTag)) {
      final schluessel = _tagSchluessel(tag);
      final trinkenRoh = trinkEintraegeNachTag[schluessel] ?? <TrinkEintrag>[];
      final trinkenIndex = List<int>.generate(trinkenRoh.length, (i) => i)
        ..sort((a, b) {
          final vergleich =
              (trinkenRoh[a].uhrzeit.hour * 60 + trinkenRoh[a].uhrzeit.minute)
                  .compareTo(
                    trinkenRoh[b].uhrzeit.hour * 60 +
                        trinkenRoh[b].uhrzeit.minute,
                  );
          return vergleich != 0 ? vergleich : a.compareTo(b);
        });
      final trinken = [for (final i in trinkenIndex) trinkenRoh[i]];
      final essen = [...(mahlzeitenNachTag[schluessel] ?? <MahlzeitEintrag>[])]
        ..sort(
          (a, b) =>
              a.minutenSeitMitternacht.compareTo(b.minutenSeitMitternacht),
        );
      final notiz = (notizenNachTag[schluessel] ?? '').trim();

      if (trinken.isNotEmpty || essen.isNotEmpty || notiz.isNotEmpty) {
        final gesamtMl = trinken.fold<int>(0, (s, e) => s + e.mengeMl);
        final liter = (gesamtMl / 1000).toStringAsFixed(2).replaceAll('.', ',');

        inhalt.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.only(bottom: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: linie)),
            ),
            width: double.infinity,
            child: pw.Text(
              '${_wochentagsnamen[tag.weekday - 1]}, ${tag.day}. '
              '${_monatsnamen[tag.month - 1]} ${tag.year}',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
          ),
        );
        inhalt.add(pw.SizedBox(height: 8));

        if (trinken.isNotEmpty) {
          inhalt.add(
            pw.Text(
              'Getrunken: $liter l',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          );
          for (final t in trinken) {
            final getraenk = t.getraenk?.trim();
            inhalt.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8, top: 2),
                child: pw.Text(
                  [
                    '${_zweistellig(t.uhrzeit.hour)}:'
                        '${_zweistellig(t.uhrzeit.minute)}',
                    '${t.mengeMl} ml',
                    if (getraenk != null && getraenk.isNotEmpty) getraenk,
                  ].join(' · '),
                ),
              ),
            );
          }
          inhalt.add(pw.SizedBox(height: 8));
        }

        if (essen.isNotEmpty) {
          if (trinken.isNotEmpty) inhalt.add(pw.SizedBox(height: 4));
          inhalt.add(
            pw.Text(
              'Mahlzeiten',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          );
          inhalt.add(pw.SizedBox(height: 4));
        }

        for (final m in essen) {
          final motivName = _motivNamen[m.essmotiv];
          final vorher = [
            if (m.hunger != null)
              'Hunger ${m.hunger! > 0 ? '+' : ''}${m.hunger}',
            if (m.essmotiv != null)
              'Motiv ${m.essmotiv}${motivName != null ? ' - $motivName' : ''}',
          ];
          final nachher = [
            if (m.saettigung != null)
              'Sättigung ${m.saettigung! > 0 ? '+' : ''}${m.saettigung}',
            if (m.energie != null) 'Energie ${m.energie}',
            if (m.stimmung != null) 'Stimmung ${m.stimmung}',
          ];

          inhalt.add(
            pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.only(left: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(left: pw.BorderSide(color: linie, width: 2)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${_zweistellig(m.minutenSeitMitternacht ~/ 60)}:'
                    '${_zweistellig(m.minutenSeitMitternacht % 60)} - '
                    '${m.text}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  if (vorher.isNotEmpty)
                    pw.Text(
                      'Vorher: ${vorher.join(' · ')}',
                      style: const pw.TextStyle(fontSize: 10, color: grau),
                    ),
                  if (nachher.isNotEmpty)
                    pw.Text(
                      'Nachher: ${nachher.join(' · ')}',
                      style: const pw.TextStyle(fontSize: 10, color: grau),
                    ),
                ],
              ),
            ),
          );
        }

        if (notiz.isNotEmpty) {
          inhalt.add(
            pw.Text(
              'Notizen & Besonderheiten',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          );
          inhalt.add(pw.SizedBox(height: 2));
          inhalt.add(pw.Text(notiz));
        }
        inhalt.add(pw.SizedBox(height: 18));
      }

      tag = DateTime(tag.year, tag.month, tag.day + 1);
    }

    if (inhalt.length == kopfLaenge) {
      inhalt.add(
        pw.Text(
          'Für diesen Zeitraum gibt es keine Einträge.',
          style: const pw.TextStyle(color: grau),
        ),
      );
    }

    dokument.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => inhalt,
      ),
    );

    final bytes = await dokument.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'ernaehrungstagebuch_${_tagSchluessel(start)}_${_tagSchluessel(ende)}.pdf',
    );
  }

  String _datumText(DateTime datum) {
    const monate = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];

    const wochentage = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];

    return '${wochentage[datum.weekday - 1]}, '
        '${datum.day}. ${monate[datum.month - 1]}';
  }

  bool get _istHeute {
    final heute = DateTime.now();

    return ausgewaehlterTag.year == heute.year &&
        ausgewaehlterTag.month == heute.month &&
        ausgewaehlterTag.day == heute.day;
  }

  Future<void> _getraenkHinzufuegen() async {
    final ergebnis = await showModalBottomSheet<(int, String?)>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: _blau),
        ),
        child: _GetraenkSheet(eigeneMengeEingeben: _eigeneMengeEingeben),
      ),
    );

    if (ergebnis == null) return;

    setState(() {
      trinkEintraege.add(
        TrinkEintrag(
          mengeMl: ergebnis.$1,
          uhrzeit: DateTime.now(),
          getraenk: ergebnis.$2,
        ),
      );
    });
    _datenSpeichern();
  }

  static const Object _mahlzeitLoeschenMarker = Object();

  Future<void> _essenEintragen([MahlzeitEintrag? bestehend]) async {
    int? ausgewaehlterHunger = bestehend?.hunger;
    String? ausgewaehltesEssmotiv = bestehend?.essmotiv;
    int? ausgewaehlteSaettigung = bestehend?.saettigung;
    int? ausgewaehlteEnergie = bestehend?.energie;
    String? ausgewaehlteStimmung = bestehend?.stimmung;
    TimeOfDay ausgewaehlteUhrzeit = bestehend == null
        ? TimeOfDay.now()
        : TimeOfDay(
            hour: bestehend.minutenSeitMitternacht ~/ 60,
            minute: bestehend.minutenSeitMitternacht % 60,
          );
    final essenController = TextEditingController(text: bestehend?.text);

    final ergebnis = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Essen eintragen',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Vor dem Essen',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: const Text('Uhrzeit'),
                      trailing: Text(
                        '${ausgewaehlteUhrzeit.hour.toString().padLeft(2, '0')}:'
                        '${ausgewaehlteUhrzeit.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      onTap: () async {
                        final gewaehlt = await showTimePicker(
                          context: context,
                          initialTime: ausgewaehlteUhrzeit,
                          builder: (context, child) {
                            return MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            );
                          },
                        );

                        if (gewaehlt != null) {
                          setModalState(() {
                            ausgewaehlteUhrzeit = gewaehlt;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Wie hungrig bist du?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),

                    Column(
                      children: [
                        _HungerOption(
                          wert: 0,
                          text: 'neutral',
                          ausgewaehlt: ausgewaehlterHunger == 0,
                          onTap: () {
                            setModalState(() {
                              ausgewaehlterHunger = 0;
                            });
                          },
                        ),
                        _HungerOption(
                          wert: -1,
                          text: 'leicht hungrig',
                          ausgewaehlt: ausgewaehlterHunger == -1,
                          onTap: () {
                            setModalState(() {
                              ausgewaehlterHunger = -1;
                            });
                          },
                        ),
                        _HungerOption(
                          wert: -2,
                          text: 'angenehm hungrig',
                          ausgewaehlt: ausgewaehlterHunger == -2,
                          onTap: () {
                            setModalState(() {
                              ausgewaehlterHunger = -2;
                            });
                          },
                        ),
                        _HungerOption(
                          wert: -3,
                          text: 'sehr hungrig',
                          ausgewaehlt: ausgewaehlterHunger == -3,
                          onTap: () {
                            setModalState(() {
                              ausgewaehlterHunger = -3;
                            });
                          },
                        ),
                        _HungerOption(
                          wert: -4,
                          text: 'heißhungrig, übel',
                          ausgewaehlt: ausgewaehlterHunger == -4,
                          onTap: () {
                            setModalState(() {
                              ausgewaehlterHunger = -4;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Warum isst du?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final motiv in const [
                          ('G', 'Gewohnheit'),
                          ('E', 'Emotionen'),
                          ('F', 'Frust'),
                          ('Ü', 'Gelüste'),
                          ('H', 'Hunger'),
                          ('L', 'Langeweile'),
                        ])
                          ChoiceChip(
                            label: Text('${motiv.$1} – ${motiv.$2}'),
                            selected: ausgewaehltesEssmotiv == motiv.$1,
                            showCheckmark: true,
                            onSelected: (_) {
                              setModalState(() {
                                ausgewaehltesEssmotiv = motiv.$1;
                              });
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Was hast du gegessen?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: essenController,
                      minLines: 3,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText:
                            'z. B. Vollkornbrot mit Frischkäse, Tomate und Ei',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      'Nach dem Essen',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Wie satt bist du?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),

                    for (final option in const [
                      (1, '+1', 'leicht satt'),
                      (2, '+2', 'angenehm satt'),
                      (3, '+3', 'sehr satt, voll'),
                      (4, '+4', 'übervoll, übel'),
                    ])
                      _HungerOption(
                        wert: option.$1,
                        kuerzel: option.$2,
                        text: option.$3,
                        ausgewaehlt: ausgewaehlteSaettigung == option.$1,
                        onTap: () {
                          setModalState(() {
                            ausgewaehlteSaettigung =
                                ausgewaehlteSaettigung == option.$1
                                ? null
                                : option.$1;
                          });
                        },
                      ),

                    const SizedBox(height: 20),

                    Text(
                      'Wie ist deine Energie?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),

                    for (final option in const [
                      (1, 'müde und schlapp'),
                      (2, 'leichte Müdigkeit'),
                      (3, 'leistungsstark und fit'),
                    ])
                      _HungerOption(
                        wert: option.$1,
                        text: option.$2,
                        ausgewaehlt: ausgewaehlteEnergie == option.$1,
                        onTap: () {
                          setModalState(() {
                            ausgewaehlteEnergie =
                                ausgewaehlteEnergie == option.$1
                                ? null
                                : option.$1;
                          });
                        },
                      ),

                    const SizedBox(height: 20),

                    Text(
                      'Wie ist deine Stimmung?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in const [
                          ('negativ', 'Negativ', Icons.sentiment_dissatisfied),
                          ('neutral', 'Neutral', Icons.sentiment_neutral),
                          ('positiv', 'Positiv', Icons.sentiment_satisfied),
                        ])
                          ChoiceChip(
                            avatar: Icon(option.$3),
                            label: Text(option.$2),
                            selected: ausgewaehlteStimmung == option.$1,
                            showCheckmark: false,
                            onSelected: (_) {
                              setModalState(() {
                                ausgewaehlteStimmung =
                                    ausgewaehlteStimmung == option.$1
                                    ? null
                                    : option.$1;
                              });
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Abbrechen'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ListenableBuilder(
                            listenable: essenController,
                            builder: (context, _) => FilledButton(
                              onPressed: essenController.text.trim().isEmpty
                                  ? null
                                  : () {
                                      Navigator.pop(
                                        context,
                                        MahlzeitEintrag(
                                          minutenSeitMitternacht:
                                              ausgewaehlteUhrzeit.hour * 60 +
                                              ausgewaehlteUhrzeit.minute,
                                          hunger: ausgewaehlterHunger,
                                          essmotiv: ausgewaehltesEssmotiv,
                                          text: essenController.text.trim(),
                                          saettigung: ausgewaehlteSaettigung,
                                          energie: ausgewaehlteEnergie,
                                          stimmung: ausgewaehlteStimmung,
                                        ),
                                      );
                                    },
                              child: const Text('Speichern'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (bestehend != null) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () async {
                          final bestaetigt = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Mahlzeit wirklich löschen?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Abbrechen'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Löschen'),
                                ),
                              ],
                            ),
                          );

                          if (bestaetigt == true && context.mounted) {
                            Navigator.pop(context, _mahlzeitLoeschenMarker);
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Löschen'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    essenController.dispose();

    if (ergebnis == null || !mounted) return;

    final liste = mahlzeitenNachTag.putIfAbsent(
      _tagSchluessel(ausgewaehlterTag),
      () => [],
    );

    setState(() {
      if (bestehend != null) {
        final index = liste.indexOf(bestehend);
        if (index >= 0) {
          if (ergebnis is MahlzeitEintrag) {
            liste[index] = ergebnis;
          } else {
            liste.removeAt(index);
          }
        }
      } else if (ergebnis is MahlzeitEintrag) {
        liste.add(ergebnis);
      }
    });
    _mahlzeitenSpeichern();
  }

  Future<int?> _eigeneMengeEingeben(BuildContext context) async {
    final controller = TextEditingController();

    return showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Andere Menge'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Menge in ml',
              suffixText: 'ml',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final menge = int.tryParse(controller.text);

                if (menge != null && menge > 0) {
                  Navigator.pop(context, menge);
                }
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        );
      },
    );
  }

  String _uhrzeit(DateTime zeit) {
    final stunde = zeit.hour.toString().padLeft(2, '0');
    final minute = zeit.minute.toString().padLeft(2, '0');

    return '$stunde:$minute';
  }

  String _mahlzeitDetails(MahlzeitEintrag m) {
    final stunde = (m.minutenSeitMitternacht ~/ 60).toString().padLeft(2, '0');
    final minute = (m.minutenSeitMitternacht % 60).toString().padLeft(2, '0');

    return [
      '$stunde:$minute Uhr',
      if (m.hunger != null) 'Hunger ${m.hunger}',
      if (m.essmotiv != null) 'Motiv ${m.essmotiv}',
    ].join(' · ');
  }

  String _mahlzeitNachher(MahlzeitEintrag m) {
    final stimmung = switch (m.stimmung) {
      'negativ' => '🙁',
      'neutral' => '😐',
      'positiv' => '🙂',
      _ => null,
    };

    final teile = [
      if (m.saettigung != null)
        'Sättigung ${m.saettigung! > 0 ? '+' : ''}${m.saettigung}',
      if (m.energie != null) 'Energie ${m.energie}',
      ?stimmung,
    ];

    return teile.isEmpty ? 'Nach dem Essen noch offen' : teile.join(' · ');
  }

  void _trinkEintragLoeschen(TrinkEintrag eintrag) {
    setState(() {
      trinkEintraege.remove(eintrag);
    });
    _datenSpeichern();
  }

  @override
  Widget build(BuildContext context) {
    final fortschritt = (getrunkeneMl / trinkZielMl).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: _hintergrund,
      appBar: AppBar(
        backgroundColor: _hintergrund,
        centerTitle: true,
        title: const Text(
          'Mein Ernährungstagebuch',
          style: TextStyle(fontWeight: FontWeight.w700, color: _navy),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // Datum
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _vorherigerTag,
                      icon: const Icon(Icons.chevron_left),
                      style: _pfeilStil,
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_istHeute)
                            const Text(
                              'HEUTE',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                                color: _terrakotta,
                              ),
                            ),
                          const SizedBox(height: 3),
                          Text(
                            _datumText(ausgewaehlterTag),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      onPressed: _istHeute ? null : _naechsterTag,
                      icon: const Icon(Icons.chevron_right),
                      style: _pfeilStil,
                    ),
                  ],
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _datensicherungOeffnen,
                      icon: const Icon(Icons.backup_outlined, size: 18),
                      label: const Text('Datensicherung'),
                      style: TextButton.styleFrom(
                        foregroundColor: _grauBlau,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _exportOeffnen,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('Export'),
                      style: TextButton.styleFrom(
                        foregroundColor: _grauBlau,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Trinken
                _BereichsKarte(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          _IconKreis(
                            icon: Icons.water_drop_outlined,
                            farbe: _blau,
                            hintergrund: _blauHell,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Trinken heute',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '$trinkMengeText von 3,0 l',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: fortschritt,
                          minHeight: 14,
                          backgroundColor: _blauHell,
                          color: _blau,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _getraenkHinzufuegen,
                          icon: const Icon(Icons.add),
                          label: const Text('Getränk hinzufügen'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _blauHell,
                            foregroundColor: _blau,
                            elevation: 0,
                          ),
                        ),
                      ),
                      if (trinkEintraege.isNotEmpty) ...[
                        const SizedBox(height: 8),

                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() {
                              trinkDetailsOffen = !trinkDetailsOffen;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${trinkEintraege.length} '
                                  '${trinkEintraege.length == 1 ? 'Eintrag' : 'Einträge'}',
                                  style: const TextStyle(color: _grauBlau),
                                ),
                                const Spacer(),
                                Text(
                                  trinkDetailsOffen
                                      ? 'Details ausblenden'
                                      : 'Details anzeigen',
                                  style: const TextStyle(
                                    color: _blau,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Icon(
                                  trinkDetailsOffen
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: _blau,
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (trinkDetailsOffen) ...[
                          const Divider(),

                          ...trinkEintraege.reversed.map(
                            (eintrag) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: const Icon(
                                Icons.local_drink_outlined,
                                color: _blau,
                              ),
                              title: Text(
                                [
                                  _uhrzeit(eintrag.uhrzeit),
                                  '${eintrag.mengeMl} ml',
                                  if (eintrag.getraenk != null)
                                    eintrag.getraenk!,
                                ].join(' · '),
                              ),
                              trailing: IconButton(
                                tooltip: 'Eintrag löschen',
                                onPressed: () => _trinkEintragLoeschen(eintrag),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Essenseinträge
                _BereichsKarte(
                  child: Column(
                    children: [
                      if (mahlzeiten.isEmpty) ...[
                        const Row(
                          children: [
                            _IconKreis(
                              icon: Icons.restaurant,
                              farbe: _terrakotta,
                              hintergrund: _terrakottaHell,
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Mahlzeiten heute',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Noch keine Mahlzeit eingetragen',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Hier erscheinen deine Einträge '
                          'für diesen Tag.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _grauBlau),
                        ),
                      ] else
                        for (final mahlzeit in mahlzeiten)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () => _essenEintragen(mahlzeit),
                            leading: const Icon(
                              Icons.restaurant,
                              color: _terrakotta,
                            ),
                            title: Text(
                              mahlzeit.text.isEmpty ? '–' : mahlzeit.text,
                            ),
                            isThreeLine: true,
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_mahlzeitDetails(mahlzeit)),
                                Text(
                                  _mahlzeitNachher(mahlzeit),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _grauBlau,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      SizedBox(height: mahlzeiten.isEmpty ? 14 : 18),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: () => _essenEintragen(),
                          icon: const Icon(Icons.add),
                          label: const Text('Essen eintragen'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Tagesnotiz
                _BereichsKarte(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          _IconKreis(
                            icon: Icons.assignment_outlined,
                            farbe: _ocker,
                            hintergrund: _ockerHell,
                          ),
                          SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Notizen & Besonderheiten',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notizController,
                        onChanged: _notizGeaendert,
                        maxLines: 4,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFFAF6EE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BereichsKarte extends StatelessWidget {
  final Widget child;

  const _BereichsKarte({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F183047),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: const EdgeInsets.all(22), child: child),
      ),
    );
  }
}

final ButtonStyle _pfeilStil = IconButton.styleFrom(
  backgroundColor: _cremeKreis,
  foregroundColor: _navy,
  disabledBackgroundColor: _cremeKreis.withValues(alpha: 0.5),
  disabledForegroundColor: _grauBlau.withValues(alpha: 0.5),
);

class _IconKreis extends StatelessWidget {
  final IconData icon;
  final Color farbe;
  final Color hintergrund;

  const _IconKreis({
    required this.icon,
    required this.farbe,
    required this.hintergrund,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: hintergrund, shape: BoxShape.circle),
      child: Icon(icon, color: farbe, size: 22),
    );
  }
}

class TrinkEintrag {
  final int mengeMl;
  final DateTime uhrzeit;
  final String? getraenk;

  TrinkEintrag({required this.mengeMl, required this.uhrzeit, this.getraenk});

  factory TrinkEintrag.fromJson(Map<String, dynamic> json) {
    return TrinkEintrag(
      mengeMl: json['mengeMl'] as int,
      uhrzeit: DateTime.parse(json['uhrzeit'] as String),
      getraenk: json['getraenk'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'mengeMl': mengeMl,
    'uhrzeit': uhrzeit.toIso8601String(),
    if (getraenk != null) 'getraenk': getraenk,
  };
}

class MahlzeitEintrag {
  final int minutenSeitMitternacht;
  final int? hunger;
  final String? essmotiv;
  final String text;
  final int? saettigung;
  final int? energie;
  final String? stimmung;

  MahlzeitEintrag({
    required this.minutenSeitMitternacht,
    required this.hunger,
    required this.essmotiv,
    required this.text,
    this.saettigung,
    this.energie,
    this.stimmung,
  });

  factory MahlzeitEintrag.fromJson(Map<String, dynamic> json) {
    return MahlzeitEintrag(
      minutenSeitMitternacht: json['minuten'] as int,
      hunger: json['hunger'] as int?,
      essmotiv: json['essmotiv'] as String?,
      text: json['text'] as String? ?? '',
      saettigung: json['saettigung'] as int?,
      energie: json['energie'] as int?,
      stimmung: json['stimmung'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'minuten': minutenSeitMitternacht,
    'hunger': hunger,
    'essmotiv': essmotiv,
    'text': text,
    'saettigung': saettigung,
    'energie': energie,
    'stimmung': stimmung,
  };
}

class _HungerOption extends StatelessWidget {
  final int wert;
  final String? kuerzel;
  final String text;
  final bool ausgewaehlt;
  final VoidCallback onTap;

  const _HungerOption({
    required this.wert,
    this.kuerzel,
    required this.text,
    required this.ausgewaehlt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: ausgewaehlt
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: ausgewaehlt
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
        child: Text(kuerzel ?? '$wert'),
      ),
      title: Text(
        text,
        style: TextStyle(
          fontWeight: ausgewaehlt ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: ausgewaehlt
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
    );
  }
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet();

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  DateTimeRange? _zeitraum;
  String? _auswahl;

  DateTime get _heute {
    final jetzt = DateTime.now();

    return DateTime(jetzt.year, jetzt.month, jetzt.day);
  }

  String _datum(DateTime d) {
    final tag = d.day.toString().padLeft(2, '0');
    final monat = d.month.toString().padLeft(2, '0');

    return '$tag.$monat.${d.year}';
  }

  void _letzteTage(int tage) {
    setState(() {
      _auswahl = '$tage';
      _zeitraum = DateTimeRange(
        start: _heute.subtract(Duration(days: tage - 1)),
        end: _heute,
      );
    });
  }

  Future<void> _zeitraumWaehlen() async {
    final gewaehlt = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _heute,
      initialDateRange: _auswahl == 'custom' ? _zeitraum : null,
    );

    if (gewaehlt == null || !mounted) return;

    setState(() {
      _auswahl = 'custom';
      _zeitraum = gewaehlt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final zeitraum = _zeitraum;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ernährungstagebuch exportieren',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Heute'),
                  selected: _auswahl == '1',
                  onSelected: (_) => _letzteTage(1),
                ),
                ChoiceChip(
                  label: const Text('Letzte 7 Tage'),
                  selected: _auswahl == '7',
                  onSelected: (_) => _letzteTage(7),
                ),
                ChoiceChip(
                  label: const Text('Letzte 14 Tage'),
                  selected: _auswahl == '14',
                  onSelected: (_) => _letzteTage(14),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: const Text('Zeitraum auswählen'),
                  selected: _auswahl == 'custom',
                  onSelected: (_) => _zeitraumWaehlen(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              zeitraum == null
                  ? 'Bitte Zeitraum wählen'
                  : '${_datum(zeitraum.start)} – ${_datum(zeitraum.end)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: zeitraum == null ? _grauBlau : null,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: zeitraum == null
                        ? null
                        : () => Navigator.pop(context, zeitraum),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF erstellen'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GetraenkSheet extends StatefulWidget {
  final Future<int?> Function(BuildContext) eigeneMengeEingeben;

  const _GetraenkSheet({required this.eigeneMengeEingeben});

  @override
  State<_GetraenkSheet> createState() => _GetraenkSheetState();
}

class _GetraenkSheetState extends State<_GetraenkSheet> {
  final TextEditingController _getraenkController = TextEditingController();
  int? _menge;
  bool _eigeneMenge = false;

  @override
  void dispose() {
    _getraenkController.dispose();
    super.dispose();
  }

  void _hinzufuegen() {
    final menge = _menge;
    if (menge == null || menge <= 0) return;

    final text = _getraenkController.text.trim();

    Navigator.pop<(int, String?)>(context, (menge, text.isEmpty ? null : text));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Wie viel hast du getrunken?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _getraenkController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Was hast du getrunken? (optional)',
                hintText: 'z. B. Wasser, Kaffee, Tee',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final menge in const [200, 250, 300, 500])
                  _MengenButton(
                    menge: menge,
                    ausgewaehlt: !_eigeneMenge && _menge == menge,
                    onPressed: () => setState(() {
                      _menge = menge;
                      _eigeneMenge = false;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _eigeneMenge && _menge != null
                ? FilledButton.tonal(
                    onPressed: _andereMengeWaehlen,
                    child: Text('Andere Menge: $_menge ml'),
                  )
                : OutlinedButton(
                    onPressed: _andereMengeWaehlen,
                    child: const Text('Andere Menge'),
                  ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _menge == null ? null : _hinzufuegen,
                    child: const Text('Hinzufügen'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _andereMengeWaehlen() async {
    final eigeneMenge = await widget.eigeneMengeEingeben(context);

    if (eigeneMenge != null && mounted) {
      setState(() {
        _menge = eigeneMenge;
        _eigeneMenge = true;
      });
    }
  }
}

class _MengenButton extends StatelessWidget {
  final int menge;
  final bool ausgewaehlt;
  final VoidCallback onPressed;

  const _MengenButton({
    required this.menge,
    required this.ausgewaehlt,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: ausgewaehlt
          ? FilledButton(onPressed: onPressed, child: Text('$menge ml'))
          : FilledButton.tonal(onPressed: onPressed, child: Text('$menge ml')),
    );
  }
}
