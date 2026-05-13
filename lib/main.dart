import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController controller;
  late Interpreter interpreter;
  late List<String> labels;
  late ImageLabeler imageLabeler;

  final TextEditingController itemController = TextEditingController();
  final TextEditingController setNameController = TextEditingController();

  Map<String, List<String>> itemSets = {
    '学校用': ['スマホ', '財布', '鍵', '充電器','イヤホン', '学生証', 'パソコン'],
    '旅行用': ['スマホ', '財布', '鍵', '充電器', '着替え', 'バッグ'],
  };

  String selectedSetName = '学校用';

  List<String> results = [];
  Set<String> detectedItems = {};
  String resultText = 'まだ判定していません';

  List<String> missingItems = [];

 final Map<String, List<String>> labelMap = {
  'スマホ': [
  'Mobile phone',
  'Phone',
  'Cell phone',
  'Telephone',
  'Smartphone',
  'Portable communications device',
],

'財布': [
  'Wallet',
  'Purse',
  'Card holder',
  'Money',
  'Billfold',
],

'鍵': [
  'Key',
  'Keys',
  'Keychain',
  'Lock',
  'House key',
],

'イヤホン': [
  'Headphones',
  'Earbuds',
  'Earphone',
  'Earphones',
  'Headset',
  'Audio equipment',
  'Audio device',
  'Wireless audio device',
  'Wireless headphones',
  'Wireless earbuds',
  'Bluetooth headset',
  'Bluetooth headphones',
  'Bluetooth earbuds',
  'AirPods',
],

'バッグ': [
  'Bag',
  'Backpack',
  'Handbag',
  'Luggage',
  'Suitcase',
  'Briefcase',
  'Shoulder bag',
  'Tote bag',
],

'水筒': [
  'Bottle',
  'Water bottle',
  'Drinkware',
  'Thermos',
  'Flask',
  'Vacuum flask',
  'Plastic bottle',
],

'パソコン': [
  'Computer',
  'Laptop',
  'Notebook computer',
  'Personal computer',
  'MacBook',
],

'腕時計': [
  'Watch',
  'Wristwatch',
  'Smartwatch',
],

'本': [
  'Book',
  'Textbook',
  'Notebook',
  'Publication',
  'Magazine',
],

'学生証': [
  'Card',
  'Identity document',
  'ID card',
  'Identification card',
  'Badge',
  'License',
],

'充電器': [
  'Cable',
  'Wire',
  'Adapter',
  'Charger',
  'USB',
  'Power supply',
  'Power adapter',
  'Charging cable',
  'USB cable',
],

'着替え': [
  'Clothing',
  'Shirt',
  'T-shirt',
  'Jeans',
  'Jacket',
  'Textile',
],
};
  List<String> get currentItems => itemSets[selectedSetName] ?? [];
Future<void> loadModel() async {
  interpreter = await Interpreter.fromAsset(
    'assets/model/model.tflite',
  );

  final labelData = await DefaultAssetBundle.of(context)
      .loadString('assets/model/labels.txt');

  labels = labelData
    .split('\n')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();
}

  @override
  void initState() {
    super.initState();

    //loadModel();
    loadItemSets();

    imageLabeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.5),
    );

    controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
    );

    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> loadItemSets() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('itemSets');
    final savedSelectedSet = prefs.getString('selectedSetName');

    if (savedData != null) {
      final decoded = jsonDecode(savedData) as Map<String, dynamic>;
      itemSets = decoded.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      );
    }

    if (savedSelectedSet != null && itemSets.containsKey(savedSelectedSet)) {
      selectedSetName = savedSelectedSet;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> saveItemSets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('itemSets', jsonEncode(itemSets));
    await prefs.setString('selectedSetName', selectedSetName);
  }

  Future<void> takePhotoAndAnalyze() async {
  final image = await controller.takePicture();

  final foundItems = <String>{};

  final inputImage = InputImage.fromFilePath(image.path);
  final imageLabels = await imageLabeler.processImage(inputImage);

  for (final imageLabel in imageLabels) {
    final mlLabel = imageLabel.label;

    print('ML Kit: $mlLabel');

    for (final item in currentItems) {
      final possibleLabels = labelMap[item];

      if (possibleLabels != null &&
          possibleLabels
              .map((e) => e.toLowerCase())
              .contains(mlLabel.toLowerCase())) {
        foundItems.add(item);
      }
    }
  }

  setState(() {
    results = foundItems.toList();
    detectedItems.addAll(foundItems);

    resultText = foundItems.isEmpty
        ? '認識できませんでした'
        : foundItems.join('、');

    missingItems = currentItems
        .where((item) => !detectedItems.contains(item))
        .toList();
  });
}
  Future<void> addItem() async {
    final newItem = itemController.text.trim();
    if (newItem.isEmpty) return;

    setState(() {
      if (!currentItems.contains(newItem)) {
        itemSets[selectedSetName]!.add(newItem);
      }
      itemController.clear();
    });

    await saveItemSets();
  }

  Future<void> removeItem(String item) async {
    setState(() {
      itemSets[selectedSetName]!.remove(item);
      detectedItems.remove(item);
    });

    await saveItemSets();
  }

  Future<void> addNewSet() async {
    final newSetName = setNameController.text.trim();
    if (newSetName.isEmpty) return;

    if (itemSets.containsKey(newSetName)) {
      setNameController.clear();
      return;
    }

    setState(() {
      itemSets[newSetName] = [];
      selectedSetName = newSetName;
      detectedItems.clear();
      results.clear();
      setNameController.clear();
    });

    await saveItemSets();
  }

  Future<void> removeCurrentSet() async {
    if (itemSets.length <= 1) return;

    setState(() {
      itemSets.remove(selectedSetName);
      selectedSetName = itemSets.keys.first;
      detectedItems.clear();
      results.clear();
    });

    await saveItemSets();
  }

  Future<void> changeSet(String? newSetName) async {
    if (newSetName == null) return;

    setState(() {
      selectedSetName = newSetName;
      detectedItems.clear();
      results.clear();
    });

    await saveItemSets();
  }

  @override
void dispose() {
  controller.dispose();
  imageLabeler.close();
  itemController.dispose();
  setNameController.dispose();
  super.dispose();
}

@override
Widget build(BuildContext context) {
  if (!controller.value.isInitialized) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  return Scaffold(
    appBar: AppBar(
      title: const Text('AI忘れ物確認'),
      actions: [
        IconButton(
      icon: const Icon(Icons.refresh),
        onPressed: () {
          setState(() {
            detectedItems.clear();
            results.clear();
            resultText = 'まだ判定していません';

             missingItems = currentItems;
           });
         },
       ),
     ],
   ),
    body: Column(
      children: [
        Expanded(
          flex: 2,
          child: CameraPreview(controller),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'セット：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: DropdownButton<String>(
                      value: selectedSetName,
                      isExpanded: true,
                      items: itemSets.keys.map((setName) {
                        return DropdownMenuItem(
                          value: setName,
                          child: Text(setName),
                        );
                      }).toList(),
                      onChanged: changeSet,
                    ),
                  ),
                  IconButton(
                    onPressed: removeCurrentSet,
                    icon: const Icon(Icons.delete),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: setNameController,
                      decoration: const InputDecoration(
                        labelText: '新しいセット名',
                        hintText: '例：キャンプ用',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: addNewSet,
                    child: const Text('作成'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: itemController,
                      decoration: const InputDecoration(
                        labelText: '荷物を追加',
                        hintText: '例：水筒',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: addItem,
                    child: const Text('追加'),
                  ),
                ],
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: takePhotoAndAnalyze,
          icon: const Icon(Icons.camera_alt),
          label: const Text('写真を撮る'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 4.0,
          ),
          child: Text(
            '未確認：${currentItems.length - detectedItems.length}個 / 全${currentItems.length}個',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '判定結果：$resultText',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (missingItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '忘れ物：${missingItems.join('、')}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          if (missingItems.isEmpty && results.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                '忘れ物なし!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),

        Expanded(
          flex: 3,
          child: currentItems.isEmpty
              ? const Center(
                  child: Text('このセットにはまだ荷物がありません'),
                )
              : ListView.builder(
                  itemCount: currentItems.length,
                  itemBuilder: (context, index) {
                    final item = currentItems[index];
                    final found = detectedItems.contains(item);

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: found
                            ? Colors.green.shade50
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          found ? Icons.check_circle : Icons.cancel,
                          color: found ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(found ? '確認済み' : '未確認'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => removeItem(item),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
}