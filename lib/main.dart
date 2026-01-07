// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:dropdown_search/dropdown_search.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';
// import 'db_helper.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDir = await getApplicationDocumentsDirectory();
  Hive.init(appDir.path);
  await Hive.openBox('localData');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AnimatedSplashScreen(
        splash: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icon/logopg_kotak.png', height: 100),
            const SizedBox(height: 10),
            const Text(
              "PG Tiket",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        nextScreen: const MainNavigation(),
        splashIconSize: 200,
        duration: 2000,
        animationDuration: const Duration(milliseconds: 800),
        splashTransition: SplashTransition.fadeTransition,
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final Color primaryColor = Color(0xFFF5B800);
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const NFCOperationScreen(),
    const CaneYardScreen(),
  ];

  void _onTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: primaryColor,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_document),
            label: 'Tiket',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.delete), label: 'Trash')
        ],
      ),
    );
  }
}

class CaneYardScreen extends StatefulWidget {
  const CaneYardScreen({super.key});

  @override
  State<CaneYardScreen> createState() => _CaneYardScreenState();
}

class _CaneYardScreenState extends State<CaneYardScreen> {
  final TextEditingController _nfcControllerBlock4 =
      TextEditingController(); //kode kebun
  final TextEditingController _nfcControllerBlock6 =
      TextEditingController(); //no tiket
  final TextEditingController _nfcControllerBlock9 =
      TextEditingController(); //logo
  final TextEditingController _nfcControllerBlock10 =
      TextEditingController(); //sopir
  final TextEditingController _nfcControllerBlock24 = TextEditingController();
  final TextEditingController _nfcControllerBlock18 = TextEditingController();
  final TextEditingController _nfcControllerBlock20 = TextEditingController();
  String? selectedTrash;
  bool isBSMChecked = false;
  bool _isScanning = false;
  bool isWriting = false;
  final Uint8List aesKey = Uint8List.fromList(utf8.encode("1234567890ABCDEF"));

  @override
  void initState() {
    super.initState();
    _startNFCContinuousListener();
  }

  Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padder = PKCS7Padding();
    final padded = Uint8List(blockSize * ((data.length ~/ blockSize) + 1));
    padded.setRange(0, data.length, data);
    final padCount = padder.addPadding(padded, data.length);
    return padded.sublist(0, data.length + padCount);
  }

  Uint8List _encryptAES(String data) {
    final key = encrypt.Key(aesKey);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(
        key,
        mode: encrypt.AESMode.ecb,
        padding: null,
      ),
    );

    final plainBytes = Uint8List.fromList(data.codeUnits);

    final padded = _pkcs7Pad(plainBytes, 16);

    final encrypted =
        encrypter.encryptBytes(padded, iv: encrypt.IV.fromLength(16));
    return Uint8List.fromList(encrypted.bytes);
  }

  Future<void> _writeNFCData({
    required String trash,
    required bool bsm,
  }) async {
    _isScanning = false;

    final Map<String, String> requiredFields = {
      'Potongan Trash': trash,
    };

    for (var entry in requiredFields.entries) {
      if (entry.value.trim().isEmpty) {
        throw Exception('${entry.key} tidak boleh kosong.');
      }
    }

    NFCTag tag = await FlutterNfcKit.poll(
      timeout: const Duration(seconds: 10),
      androidPlatformSound: true,
    );

    if (tag.type != NFCTagType.mifare_classic) {
      throw 'Tag NFC tidak kompatibel!';
    }

    Uint8List authKey =
        Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);

    Uint8List block33 = _encryptAES("1");
    Uint8List block34 = _encryptAES(trash);
    Uint8List block36 = _encryptAES("$bsm");

    await FlutterNfcKit.authenticateSector(8, keyA: authKey);
    await FlutterNfcKit.writeBlock(33, block33);
    await FlutterNfcKit.writeBlock(34, block34);

    await FlutterNfcKit.authenticateSector(9, keyA: authKey);
    await FlutterNfcKit.writeBlock(36, block36);

    await FlutterNfcKit.finish();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data berhasil dienkripsi dan ditulis ke NFC!')),
    );
    setState(() {
      _nfcControllerBlock4.clear();
      _nfcControllerBlock6.clear();
      _nfcControllerBlock9.clear();
      _nfcControllerBlock10.clear();
      _nfcControllerBlock18.clear();
      _nfcControllerBlock20.clear();
      _nfcControllerBlock24.clear();
      selectedTrash = null;
      isBSMChecked = false;
    });

    _isScanning = true;
    await Future.delayed(Duration(seconds: 5));
    _startNFCContinuousListener();
  }

  String _decryptAES(Uint8List encryptedData) {
    final encrypt.Key key = encrypt.Key(aesKey);
    final encrypt.Encrypter encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.ecb));
    final encrypt.Encrypted encrypted = encrypt.Encrypted(encryptedData);

    try {
      final decrypted =
          encrypter.decrypt(encrypted, iv: encrypt.IV.fromLength(0));
      return decrypted.trim();
    } catch (e) {
      return "";
    }
  }

  Future<void> _startNFCContinuousListener() async {
    _isScanning = true;
    while (_isScanning && mounted) {
      if (!isWriting) {
        await _startNFCListener();
      } else {
        await Future.delayed(Duration(seconds: 3));
        return;
      }
    }
  }

  Future<void> _startNFCListener() async {
    if (isWriting) return;

    try {
      NFCTag tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        androidPlatformSound: true,
      );

      if (tag.type == NFCTagType.mifare_classic) {
        Uint8List authKey =
            Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
        bool isAuthenticated =
            await FlutterNfcKit.authenticateSector(8, keyA: authKey);

        if (isAuthenticated) {
          Uint8List block32 = await FlutterNfcKit.readBlock(32);
          String isBruto = _decryptAES(block32);

          if (isBruto.isEmpty) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Gagal'),
                content: const Text('Tiket belum diproses timbangan bruto.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return;
          }

          await FlutterNfcKit.authenticateSector(1, keyA: authKey);
          Uint8List block4 = await FlutterNfcKit.readBlock(4);
          Uint8List block6 = await FlutterNfcKit.readBlock(6);

          await FlutterNfcKit.authenticateSector(2, keyA: authKey);
          Uint8List block9 = await FlutterNfcKit.readBlock(9);
          Uint8List block10 = await FlutterNfcKit.readBlock(10);

          await FlutterNfcKit.authenticateSector(4, keyA: authKey);
          Uint8List block18 = await FlutterNfcKit.readBlock(18);

          await FlutterNfcKit.authenticateSector(5, keyA: authKey);
          Uint8List block20 = await FlutterNfcKit.readBlock(20);

          await FlutterNfcKit.authenticateSector(8, keyA: authKey);
          Uint8List block34 = await FlutterNfcKit.readBlock(34);

          await FlutterNfcKit.authenticateSector(9, keyA: authKey);
          Uint8List block36 = await FlutterNfcKit.readBlock(36);

          String kodeKebun = _decryptAES(block4);
          String noTiket = _decryptAES(block6);
          String plat = _decryptAES(block9);
          String supir = _decryptAES(block10);
          String jenisTebang = _decryptAES(block18);
          String jenisTebangan = _decryptAES(block20);
          String trash = _decryptAES(block34);
          String bsm = _decryptAES(block36);
          String jenisTebu = "";

          if (['1', '2', '3', '4'].contains(kodeKebun[2])) {
            jenisTebu = 'HGU';
          } else {
            jenisTebu = 'KSO';
          }

          setState(() {
            _nfcControllerBlock4.text = kodeKebun.trim();
            _nfcControllerBlock6.text = noTiket.trim();
            _nfcControllerBlock24.text = jenisTebu.trim();
            _nfcControllerBlock9.text = plat.trim();
            _nfcControllerBlock10.text = supir.trim();
            _nfcControllerBlock18.text = jenisTebang.trim();
            _nfcControllerBlock20.text = jenisTebangan.trim();
            // if(trash != null || trash != ''){
            if (trash != '') {
              selectedTrash = trash;
            }
            // }
            if (bsm == 'true') {
              isBSMChecked = true;
            } else {
              isBSMChecked = false;
            }
          });
        } else {
          setState(() {
            _nfcControllerBlock4.text = 'Authentication failed';
          });
        }
      } else {
        setState(() {
          _nfcControllerBlock4.text = 'Unsupported NFC tag type';
        });
      }
      await Future.delayed(Duration(seconds: 1));
      await FlutterNfcKit.finish();
    } catch (e) {
      setState(() {
        // _nfcControllerBlock4.text = 'Error: $e';
      });
    }
  }

  //kode kebun, no tiket, no polisi (logo), sopir, jenis tebu, jenis tebang, jenis tebangan, potongan trash (baru)

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF5B800);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'PG Tiket',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _nfcControllerBlock4,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Kode Kebun',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nfcControllerBlock6,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'No Tiket',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nfcControllerBlock9,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Plat / No Polisi (Logo)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nfcControllerBlock10,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Supir (NIP)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nfcControllerBlock24,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Jenis Tebu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nfcControllerBlock18,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Jenis Tebang',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nfcControllerBlock20,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Jenis Tebangan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              // isExpanded: true,
              value: selectedTrash,
              decoration: const InputDecoration(
                labelText: 'Potongan Trash',
                border: OutlineInputBorder(),
              ),
              items: ['0', '5', '7.5', '10', '15']
                  .map((String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: (newValue) {
                setState(() {
                  selectedTrash = newValue;
                });
              },
            ),
            CheckboxListTile(
              title: Text('BSM'),
              value: isBSMChecked,
              onChanged: (bool? value) {
                setState(() {
                  isBSMChecked = value ?? false;
                });
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton(
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      title: const Text('Tap Kartu NFC'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Dekatkan kartu ke perangkat...'),
                        ],
                      ),
                    ),
                  );

                  try {
                    await _writeNFCData(
                        trash: selectedTrash ?? '', bsm: isBSMChecked);

                    Navigator.of(context).pop();

                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Berhasil"),
                        content: const Text("Data berhasil ditulis ke NFC."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    Navigator.of(context).pop();

                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Gagal"),
                        content: Text("Gagal menulis data ke NFC: $e"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Tutup"),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: const Text("Simpan Data"),
              ),
            ),
          ])),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _uploadAndSaveJson(BuildContext context, String keyName) async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'json']);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();

      try {
        final data = jsonDecode(content);
        if (data[keyName] != null && data[keyName] is List) {
          var box = Hive.box('localData');
          await box.put(keyName, data[keyName]);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$keyName berhasil diperbarui')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Key "$keyName" tidak ditemukan atau bukan List')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membaca file: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak ada file yang dipilih')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF5B800);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'PG Tiket',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icon/logopg_kotak.png',
                height: 120,
              ),
              const SizedBox(height: 32),
              const Text(
                'Selamat Datang',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aplikasi ini digunakan untuk operasional internal perusahaan.\nSilakan upload data melalui tombol di bawah.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // === Tombol Upload JSON ===
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildUploadButton(
                    icon: Icons.park,
                    label: 'Kebun',
                    color: Colors.green,
                    onTap: () => _uploadAndSaveJson(context, 'data_kebun'),
                  ),
                  _buildUploadButton(
                    icon: Icons.people,
                    label: 'Karyawan',
                    color: Colors.blue,
                    onTap: () => _uploadAndSaveJson(context, 'user'),
                  ),
                  _buildUploadButton(
                    icon: Icons.directions_car,
                    label: 'Truk Kontraktor',
                    color: Colors.yellow,
                    onTap: () => _uploadAndSaveJson(context, 'kendar_kontrak'),
                  ),
                  _buildUploadButton(
                    icon: Icons.directions_car,
                    label: 'Truk PG',
                    color: Colors.orange,
                    onTap: () => _uploadAndSaveJson(context, 'kendar_pg'),
                  ),
                  _buildUploadButton(
                    icon: Icons.engineering,
                    label: 'Kepala Kerja',
                    color: Colors.purple,
                    onTap: () => _uploadAndSaveJson(context, 'mandor'),
                  ),
                  _buildUploadButton(
                    icon: Icons.account_tree,
                    label: 'Huyula',
                    color: Colors.red,
                    onTap: () => _uploadAndSaveJson(context, 'huyula'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
    );
  }
}

class NFCOperationScreen extends StatefulWidget {
  const NFCOperationScreen({super.key});

  @override
  State<NFCOperationScreen> createState() => _NFCOperationScreenState();
}

class _NFCOperationScreenState extends State<NFCOperationScreen> {
  final Color primaryColor = Color(0xFFF5B800);
  final TextEditingController _nfcControllerBlock4 =
      TextEditingController(); //kode kebun
  final TextEditingController _nfcControllerBlock5 =
      TextEditingController(); //spt
  final TextEditingController _dateController =
      TextEditingController(); //tanggal jam bakar
      final TextEditingController _dateController2 =
      TextEditingController(); //tanggal jam tebang
  final TextEditingController _nfcControllerBlock6 =
      TextEditingController(); //no tiket
  // final TextEditingController _nfcControllerBlock8 = TextEditingController(); //jenis truk
  final TextEditingController _nfcControllerBlock9 =
      TextEditingController(); //nopol
  final TextEditingController _nfcControllerBlock10 =
      TextEditingController(); //supir
  final TextEditingController _nfcControllerBlock12 =
      TextEditingController(); //alat
  final TextEditingController _nfcControllerBlock13 =
      TextEditingController(); //operator
  final TextEditingController _nfcControllerBlock14 =
      TextEditingController(); //kepala kerja
  final TextEditingController _nfcControllerBlock16 =
      TextEditingController(); //huyula
  final TextEditingController _nfcControllerBlock17 =
      TextEditingController(); //jumlah tenaga kerja
  final TextEditingController _nfcControllerBlock24 = TextEditingController();
  final TextEditingController _nfcControllerBlock25 = TextEditingController();
  final TextEditingController _nfcControllerBlock26 = TextEditingController();
  final TextEditingController _nfcControllerBlock29 = TextEditingController();
  final TextEditingController _nfcControllerBlock37 = TextEditingController();
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  Map<String, String> platDropdownMap = {};
  Map<String, String> supirDropdownMap = {};
  Map<String, String> operatorDropdownMap = {};
  Map<String, String> operatorStDropdownMap = {};
  Map<String, String> mandorDropdownMap = {};
  Map<String, String> huyulaDropdownMap = {};
  Map<String, String> kebunDropdownMap = {};

  final Uint8List aesKey = Uint8List.fromList(utf8.encode("1234567890ABCDEF"));
  String? selectedJenisTebangan;
  bool isUpChecked = false;
  bool isUmbal = false;
  bool isBarak = false;
  String? selectedJenisTebang;
  bool _isScanning = false;
  bool isWriting = false;
  String? selectedJenis;
  String? selectedTruk;
  String? selectedSupir;
  String? jenisTebu;
  bool isReadOnly = false;
  String? selectedTunggul;
  String? selectedBarak;

  final List<Map<String, String>> allTruk = [
    {'id': '1', 'plat': 'L 1234 ABC', 'jenis': 'PG'},
    {'id': '2', 'plat': 'L 5678 BBB', 'jenis': 'PG'},
    {'id': '3', 'plat': 'L 4321 CBA', 'jenis': 'Kontraktor'},
    {'id': '4', 'plat': 'L 8765 ABZ', 'jenis': 'Kontraktor'},
  ];
  List<Map<String, String>> trukList = [];

  final List<Map<String, String>> supirList = [
    {'id': '1', 'nama': 'Asep'},
    {'id': '2', 'nama': 'Budi'},
    {'id': '3', 'nama': 'Coki'},
  ];

  @override
  void initState() {
    super.initState();
    _startNFCContinuousListener();
  }

  Uint8List _encodeData(String data) {
    List<int> encoded = utf8.encode(data);
    return Uint8List.fromList(
      encoded.length >= 16
          ? encoded.sublist(0, 16)
          : [...encoded, ...List.filled(16 - encoded.length, 0)],
    );
  }

  Future<void> _pickDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        DateTime finalDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          _dateController.text = finalDateTime.toString();
        });
      }
    }
  }

  Future<void> _pickDateTime2() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        DateTime finalDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          _dateController2.text = finalDateTime.toString();
        });
      }
    }
  }

  Future<void> speak(String text) async {
  await _tts.setLanguage('id-ID');
  await _tts.setSpeechRate(0.5);
  await _tts.setPitch(1.0);
  await _tts.speak(text);
}

  Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padder = PKCS7Padding();
    final padded = Uint8List(blockSize * ((data.length ~/ blockSize) + 1));
    padded.setRange(0, data.length, data);
    final padCount = padder.addPadding(padded, data.length);
    return padded.sublist(0, data.length + padCount);
  }

  Uint8List _encryptAES(String data) {
    final key = encrypt.Key(aesKey);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(
        key,
        mode: encrypt.AESMode.ecb,
        padding: null,
      ),
    );

    final plainBytes = Uint8List.fromList(data.codeUnits);

    final padded = _pkcs7Pad(plainBytes, 16);

    final encrypted =
        encrypter.encryptBytes(padded, iv: encrypt.IV.fromLength(16));
    return Uint8List.fromList(encrypted.bytes);
  }

  Future<void> _writeNFCData({
    required String kodeKebun,
    required String spt,
    required String noTiket,
    required String jenisTruk,
    required String plat,
    required String supir,
    required String alat,
    required String operator,
    required String kepalaKerja,
    required String huyula,
    required String jumlahTenagaKerja,
    required String jenisTebang,
    required String jenisTebangan,
    required String tglJamBakar,
    required String tglJamTebang,
    required String jenisTebu,
    required String operatorSt,
    required String pot,
    required bool up,
    required bool umbal,
    required String barak,
    required String alatSt,
  }) async {
    debugPrint(plat);
    debugPrint(supir);
    debugPrint(operator);
    debugPrint(kepalaKerja);
    debugPrint(huyula);
    debugPrint(operatorSt);
    _isScanning = false;

    final Map<String, String> requiredFields = {
      'Kode Kebun': kodeKebun,
      'SPT': spt,
      'No Tiket': noTiket,
      'Jenis Truk': jenisTruk,
      'Plat': plat,
      'Jenis Tebang': jenisTebang,
      'Jenis Tebangan': jenisTebangan,
      'Potongan Tunggul': pot,
      'Tinggal di Barak': barak,
      'Kepala Kerja': kepalaKerja,
      'Huyula': huyula,
      'Jumlah Tenaga Kerja': jumlahTenagaKerja,
    };

    for (var entry in requiredFields.entries) {
      if (entry.value.trim().isEmpty) {
        throw Exception('${entry.key} tidak boleh kosong.');
      }
    }

    NFCTag tag = await FlutterNfcKit.poll(
      timeout: const Duration(seconds: 5),
      androidPlatformSound: true,
    );

    if (tag.type != NFCTagType.mifare_classic) {
      throw 'Tag NFC tidak kompatibel!';
    }

    Uint8List authKey =
        Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);

    List<String> tglJamSplit = tglJamBakar.split(" ");
    String tanggal = tglJamSplit.isNotEmpty ? tglJamSplit[0] : '';
    String jamFull = tglJamSplit.length > 1 ? tglJamSplit[1] : '';
    String jam = jamFull.isNotEmpty ? jamFull.substring(0, 5) : '';

    List<String> tglJamSplit2 = tglJamTebang.split(" ");
    String tanggal2 = tglJamSplit2.isNotEmpty ? tglJamSplit2[0] : '';
    String jamFull2 = tglJamSplit2.length > 1 ? tglJamSplit2[1] : '';
    String jam2 = jamFull2.isNotEmpty ? jamFull2.substring(0, 5) : '';

    // String logo = '';
    // String nipsupir = '';
    // String nipoperator = '';
    // String nipoperatorst = '';
    // String kodemandor = '';
    // String kodehuyula = '';

    // if (plat.isNotEmpty) {
    //   List<String> platsplit = plat.split("-");
    //   logo = platsplit.isNotEmpty ? platsplit[0].trim() : '';
    // }

    // if (supir.isNotEmpty) {
    //   List<String> supirsplit = supir.split("-");
    //   nipsupir = supirsplit.isNotEmpty ? supirsplit[1].trim() : '';
    // }

    // if (operator.isNotEmpty) {
    //   List<String> operatorsplit = operator.split("-");
    //   nipoperator = operatorsplit.isNotEmpty ? operatorsplit[1].trim() : '';
    // }

    // if (operatorSt.isNotEmpty) {
    //   List<String> operatorstsplit = operatorSt.split("-");
    //   nipoperatorst =
    //       operatorstsplit.isNotEmpty ? operatorstsplit[1].trim() : '';
    // }

    // if (kepalaKerja.isNotEmpty) {
    //   List<String> mandorsplit = kepalaKerja.split("-");
    //   kodemandor = mandorsplit.isNotEmpty ? mandorsplit[0].trim() : '';
    // }

    // if (huyula.isNotEmpty) {
    //   List<String> huyulasplit = huyula.split("-");
    //   kodehuyula = huyulasplit.isNotEmpty ? huyulasplit[0].trim() : '';
    // }

    // debugPrint('======= DEBUG DATA SPLIT =======');
    // debugPrint('Tanggal: $tanggal');
    // debugPrint('Jam: $jam');
    // debugPrint('Plat (Logo): $logo');
    // debugPrint('NIP Supir: $nipsupir');
    // debugPrint('NIP Operator: $nipoperator');
    // debugPrint('NIP Operator ST: $nipoperatorst');
    // debugPrint('Kode Mandor: $kodemandor');
    // debugPrint('Kode Huyula: $kodehuyula');
    // debugPrint('=================================');

    if (jenisTruk == "PG") {
      jenisTruk = "1";
    } else if (jenisTruk == "Kontraktor") {
      jenisTruk = "2";
    }

    if (barak == 'Ya') {
      barak = 'ya';
    } else if (barak == 'Tidak') {
      barak = 'tidak';
    } else if (barak == 'Puncak Dulupi') {
      barak = 'puncak_dulupi';
    }
    Uint8List block4 = _encryptAES(kodeKebun);
    Uint8List block5 = _encryptAES(spt);
    Uint8List block6 = _encryptAES(noTiket);
    Uint8List block8 = _encryptAES(jenisTruk);
    Uint8List block9 = _encryptAES(plat);
    Uint8List block10 = _encryptAES(supir);
    Uint8List block12 = _encryptAES(alat);
    Uint8List block13 = _encryptAES(operator);
    Uint8List block14 = _encryptAES(kepalaKerja);
    Uint8List block16 = _encryptAES(huyula);
    Uint8List block17 = _encryptAES(jumlahTenagaKerja);
    Uint8List block18 = _encryptAES(jenisTebang);
    Uint8List block20 = _encryptAES(jenisTebangan);
    Uint8List block21 = _encryptAES(tanggal);
    Uint8List block22 = _encryptAES(jam);
    Uint8List block24 = _encryptAES(jenisTebu);
    Uint8List block25 = _encryptAES(operatorSt);
    Uint8List block26 = _encryptAES(pot);
    Uint8List block28 = _encryptAES("$umbal");
    Uint8List block29 = _encryptAES("$up");
    Uint8List block30 = _encryptAES(barak);
    Uint8List block37 = _encryptAES(alatSt);
    Uint8List block38 = _encryptAES(tanggal2);
    Uint8List block40 = _encryptAES(jam2);

    await FlutterNfcKit.authenticateSector(1, keyA: authKey);
    await FlutterNfcKit.writeBlock(4, block4);
    await FlutterNfcKit.writeBlock(5, block5);
    await FlutterNfcKit.writeBlock(6, block6);
    // Future.delayed(const Duration(seconds: 2));

    await FlutterNfcKit.authenticateSector(2, keyA: authKey);
    await FlutterNfcKit.writeBlock(8, block8);
    await FlutterNfcKit.writeBlock(9, block9);
    await FlutterNfcKit.writeBlock(10, block10);
    // Future.delayed(const Duration(seconds: 2));

    await FlutterNfcKit.authenticateSector(3, keyA: authKey);
    await FlutterNfcKit.writeBlock(12, block12);
    await FlutterNfcKit.writeBlock(13, block13);
    await FlutterNfcKit.writeBlock(14, block14);
    // Future.delayed(const Duration(seconds: 2));

    await FlutterNfcKit.authenticateSector(4, keyA: authKey);
    await FlutterNfcKit.writeBlock(16, block16);
    await FlutterNfcKit.writeBlock(17, block17);
    await FlutterNfcKit.writeBlock(18, block18);
    // Future.delayed(const Duration(seconds: 2));

    await FlutterNfcKit.authenticateSector(5, keyA: authKey);
    await FlutterNfcKit.writeBlock(20, block20);
    await FlutterNfcKit.writeBlock(21, block21);
    await FlutterNfcKit.writeBlock(22, block22);
    // Future.delayed(const Duration(seconds: 2));

    await FlutterNfcKit.authenticateSector(6, keyA: authKey);
    await FlutterNfcKit.writeBlock(24, block24);
    await FlutterNfcKit.writeBlock(25, block25);
    await FlutterNfcKit.writeBlock(26, block26);
    // Future.delayed(const Duration(seconds: 2));

    await FlutterNfcKit.authenticateSector(7, keyA: authKey);
    await FlutterNfcKit.writeBlock(28, block28);
    await FlutterNfcKit.writeBlock(29, block29);
    await FlutterNfcKit.writeBlock(30, block30);

    await FlutterNfcKit.authenticateSector(9, keyA: authKey);
    await FlutterNfcKit.writeBlock(37, block37);
    await FlutterNfcKit.writeBlock(38, block38);

    await FlutterNfcKit.authenticateSector(10, keyA: authKey);
    await FlutterNfcKit.writeBlock(40, block40);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data berhasil dienkripsi dan ditulis ke NFC!')),
    );

    setState(() {
      _nfcControllerBlock4.clear();
      _nfcControllerBlock5.clear();
      _nfcControllerBlock6.clear();
      _nfcControllerBlock9.clear();
      _nfcControllerBlock10.clear();
      _nfcControllerBlock12.clear();
      _nfcControllerBlock13.clear();
      _nfcControllerBlock14.clear();
      _nfcControllerBlock16.clear();
      _nfcControllerBlock17.clear();
      _nfcControllerBlock24.clear();
      _nfcControllerBlock25.clear();
      _nfcControllerBlock37.clear();
      _dateController.clear();
      _dateController2.clear();
      selectedJenis = null;
      // selectedTruk = null;
      // selectedSupir = null;
      selectedJenisTebangan = null;
      selectedJenisTebang = null;
      _nfcControllerBlock26.clear();
      isUpChecked = false;
      isUmbal = false;
      selectedBarak = null;
      selectedTunggul = null;
      // _nfcControllerBlock29.clear();
    });

    await Future.delayed(Duration(seconds: 2));
    await FlutterNfcKit.finish();

    _isScanning = true;
    // await Future.delayed(Duration(seconds: 5));
    _startNFCContinuousListener();
  }

  Future<void> _startNFCContinuousListener() async {
    _isScanning = true;
    while (_isScanning && mounted) {
      if (!isWriting) {
        await _startNFCListener();
      } else {
        await Future.delayed(Duration(seconds: 3)); 
        return;
      }
    }
  }

  Future<void> _startNFCListener() async {
    try {
      NFCTag tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        androidPlatformSound: true,
      );

      if (tag.type == NFCTagType.mifare_classic) {
        Uint8List authKey =
            Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
        bool isAuthenticated =
            await FlutterNfcKit.authenticateSector(1, keyA: authKey);

        if (isAuthenticated) {
          Uint8List block4 = await FlutterNfcKit.readBlock(4);
          Uint8List block5 = await FlutterNfcKit.readBlock(5);
          Uint8List block6 = await FlutterNfcKit.readBlock(6);

          String kodeKebun = _decryptAES(block4);
          String spt = _decryptAES(block5);
          String noTiket = _decryptAES(block6);

          await FlutterNfcKit.authenticateSector(8, keyA: authKey);
          Uint8List block32 = await FlutterNfcKit.readBlock(32);
          String isBruto = _decryptAES(block32);

          if (kodeKebun.isEmpty || spt.isEmpty || noTiket.isEmpty) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Gagal'),
                content: const Text('Data tiket tidak lengkap.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return;
          } else if (isBruto == '1') {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Gagal'),
                content: const Text('Data sudah diproses di bruto.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return;
          }

          await FlutterNfcKit.authenticateSector(2, keyA: authKey);
          Uint8List block8 = await FlutterNfcKit.readBlock(8);
          Uint8List block9 = await FlutterNfcKit.readBlock(9);
          Uint8List block10 = await FlutterNfcKit.readBlock(10);

          await FlutterNfcKit.authenticateSector(3, keyA: authKey);
          Uint8List block12 = await FlutterNfcKit.readBlock(12);
          Uint8List block13 = await FlutterNfcKit.readBlock(13);
          Uint8List block14 = await FlutterNfcKit.readBlock(14);

          await FlutterNfcKit.authenticateSector(4, keyA: authKey);
          Uint8List block16 = await FlutterNfcKit.readBlock(16);
          Uint8List block17 = await FlutterNfcKit.readBlock(17);
          Uint8List block18 = await FlutterNfcKit.readBlock(18);

          await FlutterNfcKit.authenticateSector(5, keyA: authKey);
          Uint8List block20 = await FlutterNfcKit.readBlock(20);
          Uint8List block21 = await FlutterNfcKit.readBlock(21);
          Uint8List block22 = await FlutterNfcKit.readBlock(22);

          await FlutterNfcKit.authenticateSector(6, keyA: authKey);
          Uint8List block24 = await FlutterNfcKit.readBlock(24);
          Uint8List block25 = await FlutterNfcKit.readBlock(25);
          Uint8List block26 = await FlutterNfcKit.readBlock(26);

          await FlutterNfcKit.authenticateSector(7, keyA: authKey);
          Uint8List block28 = await FlutterNfcKit.readBlock(28);
          Uint8List block29 = await FlutterNfcKit.readBlock(29);
          Uint8List block30 = await FlutterNfcKit.readBlock(30);

          await FlutterNfcKit.authenticateSector(9, keyA: authKey);
          Uint8List block37 = await FlutterNfcKit.readBlock(37);

          // print("Block 32: $block32");
          String jenisTruk = _decryptAES(block8);
          String plat = _decryptAES(block9);
          debugPrint("block 9: $plat");
          String supir = _decryptAES(block10);
          String alat = _decryptAES(block12);
          String operator = _decryptAES(block13);
          String kepalaKerja = _decryptAES(block14);
          String huyula = _decryptAES(block16);
          String jumlahTenagaKerja = _decryptAES(block17);
          String jenisTebang = _decryptAES(block18);
          String jenisTebangan = _decryptAES(block20);
          String tanggal = _decryptAES(block21);
          String jam = _decryptAES(block22);
          String operatorSt = _decryptAES(block25);
          String pot = _decryptAES(block26);
          String up = _decryptAES(block29);
          String umbal = _decryptAES(block28);
          String barak = _decryptAES(block30);
          String alatSt = _decryptAES(block37);
          debugPrint(barak);
          String jenisTebu = "";

          if (['1', '2', '3', '4'].contains(kodeKebun[2])) {
            jenisTebu = 'HGU';
          } else {
            jenisTebu = 'KSO';
          }

          if (jenisTruk == "1") {
            jenisTruk = "PG";
          } else if (jenisTruk == "2") {
            jenisTruk = "Kontraktor";
          }

          if (barak == 'ya') {
            barak = 'Ya';
          } else if (barak == 'tidak') {
            barak = 'Tidak';
          } else if (barak == 'puncak_dulupi') {
            barak = 'Puncak Dulupi';
          }

          // print("isBruto:$isBruto");
          // if (isBruto.isNotEmpty) {
          //   isReadOnly = true;
          // }

          String tanggalJam = "${tanggal} ${jam}";

          setState(() {
            _nfcControllerBlock4.text = kodeKebun.trim();
            _nfcControllerBlock5.text = spt.trim();
            _nfcControllerBlock6.text = noTiket.trim();
            _nfcControllerBlock24.text = jenisTebu.trim();
            if (jenisTruk != "") {
              selectedJenis = jenisTruk;
            }
            _nfcControllerBlock9.text = plat.trim();
            _nfcControllerBlock10.text = supir.trim();
            _nfcControllerBlock12.text = alat.trim();
            _nfcControllerBlock13.text = operator.trim();
            _nfcControllerBlock14.text = kepalaKerja.trim();
            _nfcControllerBlock16.text = huyula.trim();
            _nfcControllerBlock17.text = jumlahTenagaKerja.trim();
            _nfcControllerBlock37.text = alatSt.trim();
            if (jenisTebang != "") {
              selectedJenisTebang = jenisTebang;
            }
            if (jenisTebangan != "") {
              selectedJenisTebangan = jenisTebangan;
            }

            if (up == "true") {
              isUpChecked = true;
            } else {
              isUpChecked = false;
            }
            if (umbal == "true") {
              isUmbal = true;
            } else {
              isUmbal = false;
            }
            if (barak.isNotEmpty) {
              selectedBarak = barak;
            }
            _dateController.text = tanggalJam.trim();
            _nfcControllerBlock25.text = operatorSt.trim();
            if (pot != "") {
              selectedTunggul = pot;
            }
            final box = Hive.box('localData');

            //untuk kebunDropDownMap
            final listKebun = box.get('data_kebun') as List<dynamic>? ?? [];
            kebunDropdownMap.clear();
            for (var e in listKebun) {
              final map = Map<String, dynamic>.from(e);
              final value = map['KODEKEBUN'] ?? '';
              final label = "${map['KODEKEBUN']} - ${map['NOPETAK']} - ${map['LUASHA']} HA - ${map['LOKASI']}";
              kebunDropdownMap[value] = label;
            }

            // // Untuk platDropdownMap
            final listPG = box.get('kendar_pg') as List<dynamic>? ?? [];
            final listKontrak =
                box.get('kendar_kontrak') as List<dynamic>? ?? [];

            platDropdownMap.clear();
            if (selectedJenis == 'PG') {
              for (var e in listPG) {
                final map = Map<String, dynamic>.from(e);
                final value = map['NOKENDAR'] ?? '';
                final label = "${map['KODESUB']} - ${map['NOKENDAR']}";
                platDropdownMap[value] = label;
              }
            } else if (selectedJenis == 'Kontraktor') {
              for (var e in listKontrak) {
                final map = Map<String, dynamic>.from(e);
                final value = map['KODELANG'] ?? '';
                final label =
                    "${map['KODELANG']} - ${map['PNAMLANG']} - ${map['POLISI']}";
                platDropdownMap[value] = label;
              }
            }

            final listMandor = box.get('mandor') as List<dynamic>? ?? [];
            mandorDropdownMap.clear();
            for (var e in listMandor) {
              final map = Map<String, dynamic>.from(e);
              final value = map['KODEMAN'] ?? '';
              final label = "${map['KODEMAN']} - ${map['NAMAMAN']}";
              mandorDropdownMap[value] = label;
            }

            final listHuyula = box.get('huyula') as List<dynamic>? ?? [];
            huyulaDropdownMap.clear();
            for (var e in listHuyula) {
              final map = Map<String, dynamic>.from(e);
              final value = map['KODEHUYULA'] ?? '';
              final label = "${map['KODEHUYULA']} - ${map['NAMAHUYULA']}";
              huyulaDropdownMap[value] = label;
            }

            final listUser = box.get('user') as List<dynamic>? ?? [];
            supirDropdownMap.clear();
            for (var e in listUser) {
              final map = Map<String, dynamic>.from(e);
              final nip = map['nip'] ?? '';
              final nama = map['nama'] ?? '';
              if (nip.length >= 4) {
                final key = nip.substring(3, 7);
                final label = "$nip - $nama";
                supirDropdownMap[key] = label;
              }
            }
            final listOp = box.get('user') as List<dynamic>? ?? [];
            operatorDropdownMap.clear();
            for (var e in listOp) {
              final map = Map<String, dynamic>.from(e);
              final nip = map['nip'] ?? '';
              final nama = map['nama'] ?? '';
              if (nip.length >= 4) {
                final key = nip.substring(3, 7);
                final label = "$nip - $nama";
                operatorDropdownMap[key] = label;
              }
            }
            final listSt = box.get('user') as List<dynamic>? ?? [];
            operatorStDropdownMap.clear();
            for (var e in listSt) {
              final map = Map<String, dynamic>.from(e);
              final nip = map['nip'] ?? '';
              final nama = map['nama'] ?? '';
              if (nip.length >= 4) {
                final key = nip.substring(3, 7);
                final label = "$nip - $nama";
                operatorStDropdownMap[key] = label;
              }
            }
          });
        } else {
          setState(() {
            _nfcControllerBlock5.text = 'Authentication failed';
          });
        }
      } else {
        setState(() {
          _nfcControllerBlock5.text = 'Unsupported NFC tag type';
        });
      }
      await Future.delayed(Duration(seconds: 1));
      await FlutterNfcKit.finish();
    } catch (e) {
      setState(() {
        // _nfcControllerBlock4.text = 'Error: $e';
      });
    }
  }

  String _decryptAES(Uint8List encryptedData) {
    final encrypt.Key key = encrypt.Key(aesKey);
    final encrypt.Encrypter encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.ecb));
    final encrypt.Encrypted encrypted = encrypt.Encrypted(encryptedData);

    try {
      final decrypted =
          encrypter.decrypt(encrypted, iv: encrypt.IV.fromLength(0));
      return decrypted.trim();
    } catch (e) {
      return "";
    }
  }

  Future<void> playSound(String fileName) async {
    await _player.play(AssetSource('sfx/$fileName'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'PG Tiket',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TextField(
            //   controller: _nfcControllerBlock4,
            //   readOnly: true,
            //   decoration: const InputDecoration(
            //     labelText: 'Kode Kebun',
            //     border: OutlineInputBorder(),
            //   ),
            // ),
            DropdownSearch<String>(
              enabled: !isReadOnly,
              asyncItems: (String filter) async {
                final list =
                    Hive.box('localData').get('data_kebun') as List<dynamic>? ??
                        [];
                return list.map((e) {
                  final map = Map<String, dynamic>.from(e);
                  final kode = map['KODEKEBUN'] ?? '';
                  final petak = map['NOPETAK'] ?? '';
                  final luas = map['LUASHA'] ?? '';
                  final lokasi = map['LOKASI'] ?? '';
                  return "$kode - $petak - $luas HA - $lokasi";
                }).toList();
              },
              selectedItem: kebunDropdownMap[_nfcControllerBlock4.text],
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Kode Kebun',
                  border: OutlineInputBorder(),
                ),
              ),
              onChanged: (value) {
                if (value != null && value.contains('-')) {
                  final parts = value.split('-');
                  if (parts.length >= 2) {
                    final kode = parts[0].trim();
                    _nfcControllerBlock4.text = kode;
                  } else {
                    _nfcControllerBlock4.text = value;
                  }
                } else {
                  _nfcControllerBlock4.text = '';
                }
                setState(() {});
              },
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    labelText: 'Cari Kebun',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nfcControllerBlock5,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'SPT',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nfcControllerBlock6,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'No Tiket',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedJenis,
              decoration: const InputDecoration(
                labelText: 'Jenis Truk',
                border: OutlineInputBorder(),
              ),
              items: ['PG', 'Kontraktor']
                  .map((String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: isReadOnly
                  ? null
                  : (newValue) {
                      setState(() {
                        selectedJenis = newValue;
                      });
                    },
            ),

            const SizedBox(height: 16),
            DropdownSearch<String>(
              enabled: !isReadOnly,
              asyncItems: (String filter) async {
                var box = Hive.box('localData');
                List<String> dropdownItems = [];
                if (selectedJenis == 'PG') {
                  final list = box.get('kendar_pg') as List<dynamic>? ?? [];

                  dropdownItems = list.map((e) {
                    final map = Map<String, dynamic>.from(e);
                    final value = map['NOKENDAR'] ?? '';
                    final label = "${map['KODESUB']} - ${map['NOKENDAR']}";
                    platDropdownMap[value] = label;
                    return label;
                  }).toList();
                } else if (selectedJenis == 'Kontraktor') {
                  final list =
                      box.get('kendar_kontrak') as List<dynamic>? ?? [];

                  dropdownItems = list.map((e) {
                    final map = Map<String, dynamic>.from(e);
                    final value = map['KODELANG'] ?? '';
                    final label =
                        "${map['KODELANG']} - ${map['PNAMLANG']} - ${map['POLISI']}";
                    platDropdownMap[value] = label;
                    return label;
                  }).toList();
                }

                return dropdownItems;
              },
              selectedItem: platDropdownMap[_nfcControllerBlock9.text],
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'No Polisi / Plat (Logo)',
                  border: OutlineInputBorder(),
                ),
              ),
              onChanged: (value) {
                if (value != null && value.contains(' - ')) {
                  if (selectedJenis == 'PG') {
                    _nfcControllerBlock9.text = value.split(' - ').last.trim();
                  } else if (selectedJenis == 'Kontraktor') {
                    _nfcControllerBlock9.text = value.split(' - ').first.trim();
                  }
                } else {
                  _nfcControllerBlock9.text = '';
                }
                setState(() {});
              },
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    labelText: 'Cari Truk',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            DropdownSearch<String>(
              enabled: !isReadOnly,
              asyncItems: (String filter) async {
                final list =
                    Hive.box('localData').get('user') as List<dynamic>? ?? [];
                return list.map((e) {
                  final map = Map<String, dynamic>.from(e);
                  final nip = map['nip'] ?? '';
                  final nama = map['nama'] ?? '';
                  return "$nip - $nama";
                }).toList();
              },
              selectedItem: supirDropdownMap[_nfcControllerBlock10.text],
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Supir (NIP)',
                  border: OutlineInputBorder(),
                ),
              ),
              onChanged: (value) {
                if (value != null && value.contains('-')) {
                  final parts = value.split('-');
                  if (parts.length >= 2) {
                    final nipPart = parts[1].trim();
                    _nfcControllerBlock10.text = nipPart;
                  } else {
                    _nfcControllerBlock10.text = value;
                  }
                } else {
                  _nfcControllerBlock10.text = '';
                }
                setState(() {});
              },
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    labelText: 'Cari Supir',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nfcControllerBlock12,
              readOnly: isReadOnly,
              decoration: const InputDecoration(
                labelText: 'Alat',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            DropdownSearch<String>(
              enabled: !isReadOnly,
              asyncItems: (String filter) async {
                final list =
                    Hive.box('localData').get('user') as List<dynamic>? ?? [];
                return list.map((e) {
                  final map = Map<String, dynamic>.from(e);
                  final nip = map['nip'] ?? '';
                  final nama = map['nama'] ?? '';
                  return "$nip - $nama";
                }).toList();
              },
              selectedItem: operatorDropdownMap[_nfcControllerBlock13.text],
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Operator (NIP)',
                  border: OutlineInputBorder(),
                ),
              ),
              onChanged: (value) {
                if (value != null && value.contains('-')) {
                  final parts = value.split('-');
                  if (parts.length >= 2) {
                    final nipPart = parts[1].trim();
                    _nfcControllerBlock13.text = nipPart;
                  } else {
                    _nfcControllerBlock13.text = value;
                  }
                } else {
                  _nfcControllerBlock13.text = '';
                }
                setState(() {});
              },
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    labelText: 'Cari Operator',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nfcControllerBlock37,
              readOnly: isReadOnly,
              decoration: const InputDecoration(
                labelText: 'Alat ST',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownSearch<String>(
              enabled: !isReadOnly,
              asyncItems: (String filter) async {
                final list =
                    Hive.box('localData').get('user') as List<dynamic>? ?? [];
                return list.map((e) {
                  final map = Map<String, dynamic>.from(e);
                  final nip = map['nip'] ?? '';
                  final nama = map['nama'] ?? '';
                  return "$nip - $nama";
                }).toList();
              },
              selectedItem: operatorStDropdownMap[_nfcControllerBlock25.text],
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Operator ST (NIP)',
                  border: OutlineInputBorder(),
                ),
              ),
              onChanged: (value) {
                if (value != null && value.contains('-')) {
                  final parts = value.split('-');
                  if (parts.length >= 2) {
                    final nipPart = parts[1].trim();
                    _nfcControllerBlock25.text = nipPart;
                  } else {
                    _nfcControllerBlock25.text = value;
                  }
                } else {
                  _nfcControllerBlock25.text = '';
                }
                setState(() {});
              },
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    labelText: 'Cari Operator ST',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            DropdownSearch<String>(
              enabled: !isReadOnly,
              asyncItems: (String filter) async {
                final list =
                    Hive.box('localData').get('mandor') as List<dynamic>? ?? [];

                List<String> items = list.map((e) {
                  final map = Map<String, dynamic>.from(e);
                  final value = map['KODEMAN'] ?? '';
                  final label = "${map['KODEMAN']} - ${map['NAMAMAN']}";
                  mandorDropdownMap[value] = label;
                  return label;
                }).toList();

                return items;
              },
              selectedItem: mandorDropdownMap[_nfcControllerBlock14.text],
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Kepala Kerja (Kode Mandor)',
                  border: OutlineInputBorder(),
                ),
              ),
              onChanged: (value) {
                if (value != null && value.contains(' - ')) {
                  _nfcControllerBlock14.text = value.split(' - ').first.trim();
                } else {
                  _nfcControllerBlock14.text = value ?? '';
                }
                setState(() {});
              },
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    labelText: 'Cari Kepala Kerja',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            DropdownSearch<String>(
              enabled: !isReadOnly,
              asyncItems: (String filter) async {
                final list =
                    Hive.box('localData').get('huyula') as List<dynamic>? ?? [];

                List<String> items = list.map((e) {
                  final map = Map<String, dynamic>.from(e);
                  final value = map['KODEHUYULA'] ?? '';
                  final label = "${map['KODEHUYULA']} - ${map['NAMAHUYULA']}";
                  huyulaDropdownMap[value] = label;
                  return label;
                }).toList();

                return items;
              },
              selectedItem: huyulaDropdownMap[_nfcControllerBlock16.text],
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Huyula (Kode Huyula)',
                  border: OutlineInputBorder(),
                ),
              ),
              onChanged: (value) {
                if (value != null && value.contains(' - ')) {
                  _nfcControllerBlock16.text = value.split(' - ').first.trim();
                } else {
                  _nfcControllerBlock16.text = value ?? '';
                }
                setState(() {});
              },
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    labelText: 'Cari Huyula',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _nfcControllerBlock17,
              readOnly: isReadOnly,
              decoration: const InputDecoration(
                labelText: 'Jumlah Tenaga Kerja',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nfcControllerBlock24,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Jenis Tebu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedJenisTebang,
                    decoration: const InputDecoration(
                      labelText: 'Jenis Tebang',
                      border: OutlineInputBorder(),
                    ),
                    items: ['BC', 'LC', 'CC', 'RS']
                        .map((String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: isReadOnly
                        ? null
                        : (newValue) {
                            setState(() {
                              selectedJenisTebang = newValue;
                            });
                          },
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedJenisTebangan,
                    decoration: const InputDecoration(
                      labelText: 'Jenis Tebangan',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Hijau', 'Bakar']
                        .map((String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: isReadOnly
                        ? null
                        : (newValue) {
                            setState(() {
                              selectedJenisTebangan = newValue;
                              if (newValue == 'Bakar') {
                                _dateController2.clear();
                              } else if (newValue == 'Hijau') {
                                _dateController.clear();
                              }
                            });
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Date Picker
            if (selectedJenisTebangan == 'Bakar') ...[
              TextField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Tanggal & Jam Bakar',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: isReadOnly ? null : _pickDateTime,
                  ),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
            ],
            if (selectedJenisTebangan == 'Hijau') ...[
              TextField(
                controller: _dateController2,
                decoration: InputDecoration(
                  labelText: 'Tanggal & Jam Tebang',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: isReadOnly ? null : _pickDateTime2,
                  ),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              value: selectedTunggul,
              decoration: const InputDecoration(
                labelText: 'Potongan Tunggul',
                border: OutlineInputBorder(),
              ),
              items: ['0', '5', '7.5', '10', '15', '20']
                  .map((String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: isReadOnly
                  ? null
                  : (newValue) {
                      setState(() {
                        selectedTunggul = newValue;
                      });
                    },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedBarak,
              decoration: const InputDecoration(
                labelText: 'Tinggal di Barak',
                border: OutlineInputBorder(),
              ),
              items: ['Ya', 'Tidak', 'Puncak Dulupi']
                  .map((String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: isReadOnly
                  ? null
                  : (newValue) {
                      setState(() {
                        selectedBarak = newValue;
                      });
                    },
            ),

            // const SizedBox(height: 16),
            CheckboxListTile(
              title: Text('Premi Umbal'),
              value: isUmbal,
              onChanged: isReadOnly
                  ? null
                  : (bool? value) {
                      setState(() {
                        isUmbal = value ?? false;
                      });
                    },
            ),
            CheckboxListTile(
              title: Text('Aff Petak'),
              value: isUpChecked,
              onChanged: isReadOnly
                  ? null
                  : (bool? value) {
                      setState(() {
                        isUpChecked = value ?? false;
                      });
                    },
            ),
            // const SizedBox(height: 16),
            // CheckboxListTile(
            //   title: Text('Tinggal di Barak'),
            //   value: isBarak,
            //   onChanged: isReadOnly
            //       ? null
            //       : (bool? value) {
            //           setState(() {
            //             isBarak = value ?? false;
            //           });
            //         },
            // ),

            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton(
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      title: const Text('Tap Kartu NFC'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Dekatkan kartu ke perangkat...'),
                        ],
                      ),
                    ),
                  );

                  try {
                    print('====== Debug Data Sebelum Write NFC ======');
                    print('kodeKebun: ${_nfcControllerBlock4.text}');
                    print('spt: ${_nfcControllerBlock5.text}');
                    print('noTiket: ${_nfcControllerBlock6.text}');
                    print('jenisTruk: $selectedJenis');
                    print('plat: ${_nfcControllerBlock9.text}');
                    print('supir: ${_nfcControllerBlock10.text}');
                    print('alat: ${_nfcControllerBlock12.text}');
                    print('alat ST: ${_nfcControllerBlock37.text}');
                    print('operator: ${_nfcControllerBlock13.text}');
                    print('kepalaKerja: ${_nfcControllerBlock14.text}');
                    print('huyula: ${_nfcControllerBlock16.text}');
                    print('jumlahTenagaKerja: ${_nfcControllerBlock17.text}');
                    print('jenisTebu: ${_nfcControllerBlock24.text}');
                    print('jenisTebang: $selectedJenisTebang');
                    print('jenisTebangan: $selectedJenisTebangan');
                    print('pot: $selectedTunggul');
                    print('up: $isUpChecked');
                    print('umbal: $isUmbal');
                    print('barak: $selectedBarak');
                    print('tglJamBakar: ${_dateController.text}');
                    print('operatorSt: ${_nfcControllerBlock25.text}');
                    print('==========================================');
                    await _writeNFCData(
                        kodeKebun: _nfcControllerBlock4.text ?? '',
                        spt: _nfcControllerBlock5.text ?? '',
                        noTiket: _nfcControllerBlock6.text ?? '',
                        jenisTruk: selectedJenis ?? '',
                        plat: _nfcControllerBlock9.text ?? '',
                        supir: _nfcControllerBlock10.text ?? '',
                        alat: _nfcControllerBlock12.text ?? '',
                        operator: _nfcControllerBlock13.text ?? '',
                        kepalaKerja: _nfcControllerBlock14.text ?? '',
                        huyula: _nfcControllerBlock16.text ?? '',
                        jumlahTenagaKerja: _nfcControllerBlock17.text ?? '',
                        jenisTebu: _nfcControllerBlock24.text ?? '',
                        jenisTebang: selectedJenisTebang ?? '',
                        jenisTebangan: selectedJenisTebangan ?? '',
                        pot: selectedTunggul ?? '',
                        // gantiKebun: _editableOption,
                        up: isUpChecked,
                        umbal: isUmbal,
                        barak: selectedBarak ?? '',
                        tglJamBakar: _dateController.text.isNotEmpty
                            ? _dateController.text
                            : '',
                        tglJamTebang: _dateController2.text.isNotEmpty
                            ? _dateController2.text
                            : '',
                        operatorSt: _nfcControllerBlock25.text,
                        alatSt: _nfcControllerBlock37.text);
                    Navigator.of(context).pop();

                    // await playSound('Berhasil.mp3');
                    await speak("Sip Berhasil");
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Berhasil"),
                        content: const Text("Data berhasil ditulis ke NFC."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    Navigator.of(context).pop();

                    String errorMessage;

                    if (e is PlatformException) {
                      if (e.code == '408') {
                        // await playSound('Error.mp3');
                        errorMessage =
                            "Timeout saat menulis ke NFC. Silahkan coba lagi";
                      } else if (e.code == '500') {
                        await playSound('Gagal.mp3');
                        errorMessage =
                            "Kesalahan saat tap kartu. Silahkan coba lagi";
                      } else {
                        errorMessage = "PlatformException: ${e.message}";
                      }
                    } else {
                      errorMessage = "Terjadi kesalahan: $e";
                    }
                    await speak("Gagal silahkan coba lagi");

                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Gagal"),
                        content: Text(errorMessage),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Tutup"),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: const Text("Simpan Data"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
