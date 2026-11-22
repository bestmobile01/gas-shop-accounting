import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const GasShopApp());
}

class GasShopApp extends StatelessWidget {
  const GasShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'গ্যাস ও দোকানের হিসাব',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeAccountingScreen(),
    );
  }
}

class HomeAccountingScreen extends StatefulWidget {
  const HomeAccountingScreen({super.key});

  @override
  State<HomeAccountingScreen> createState() => _HomeAccountingScreenState();
}

class _HomeAccountingScreenState extends State<HomeAccountingScreen> {
  double cashBalance = 300000;
  double mfsBalance = 0;
  double bankBalance = 0;
  double shopAdvance = 300000;
  double loanPrincipalDue = 8200 + 22000;

  List> items = [
    {
      'name': 'বসুন্ধরা ১২ কেজি গ্যাস',
      'full': 7,
      'empty': 0,
      'sellPrice': 2400.0,
      'bottlePrice': 1300.0,
    },
    {
      'name': 'চুলা / রেগুলেটর / পাইপ',
      'full': 5,
      'empty': 0,
      'sellPrice': 1500.0,
      'bottlePrice': 0.0,
    },
  ];

  Map<String, Map<String, dynamic>> customers = {
    'নাফিজা': {'cashDue': 300.0, 'bottleDue': 1},
    'হারুন হোটেল': {'cashDue': 1900.0, 'bottleDue': 1},
    'বাবা': {'cashDue': 2300.0, 'bottleDue': 0},
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_state_v1');
    if (saved != null) {
      final data = jsonDecode(saved);
      setState(() {
        cashBalance = (data['cashBalance'] ?? cashBalance).toDouble();
        mfsBalance = (data['mfsBalance'] ?? mfsBalance).toDouble();
        bankBalance = (data['bankBalance'] ?? bankBalance).toDouble();
        shopAdvance = (data['shopAdvance'] ?? shopAdvance).toDouble();
        loanPrincipalDue = (data['loanPrincipalDue'] ?? loanPrincipalDue).toDouble();
        if (data['items'] != null) {
          items = List>.from(data['items']);
        }
        if (data['customers'] != null) {
          customers = Map<String, Map<String, dynamic>>.from(
            (data['customers'] as Map).map(
              (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v)),
            ),
          );
        }
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'app_state_v1',
      jsonEncode({
        'cashBalance': cashBalance,
        'mfsBalance': mfsBalance,
        'bankBalance': bankBalance,
        'shopAdvance': shopAdvance,
        'loanPrincipalDue': loanPrincipalDue,
        'items': items,
        'customers': customers,
      }),
    );
  }

  void _openSaleDialog() {
    String selectedCustomer = customers.keys.first;
    int selectedItemIdx = 0;
    final qtyCtrl = TextEditingController(text: '1');
    final discountCtrl = TextEditingController(text: '0');
    final exchangeCtrl = TextEditingController(text: '1');
    final cashPaidCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নতুন বিক্রি এন্ট্রি'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCustomer,
                decoration: const InputDecoration(labelText: 'কাস্টমার'),
                items: customers.keys
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) selectedCustomer = val;
                },
              ),
              DropdownButtonFormField<int>(
                value: selectedItemIdx,
                decoration: const InputDecoration(labelText: 'পণ্য / সিলিন্ডার'),
                items: List.generate(
                  items.length,
                  (i) => DropdownMenuItem(
                    value: i,
                    child: Text(items[i]['name']),
                  ),
                ),
                onChanged: (val) {
                  if (val != null) selectedItemIdx = val;
                },
              ),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'পরিমাণ (কয়টি)'),
              ),
              TextField(
                controller: discountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ডিসকাউন্ট (টাকা)'),
              ),
              TextField(
                controller: exchangeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'বোতল এক্সচেঞ্জ (ফেরত দেওয়া বোতল)'),
              ),
              TextField(
                controller: cashPaidCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'নগদ জমা (টাকা)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text) ?? 1;
              final discount = double.tryParse(discountCtrl.text) ?? 0;
              final exchanged = int.tryParse(exchangeCtrl.text) ?? 0;
              final paidCash = double.tryParse(cashPaidCtrl.text) ?? 0;

              final item = items[selectedItemIdx];
              final unitPrice = (item['sellPrice'] as num).toDouble();
              final netTotal = (qty * unitPrice) - discount;
              final cashDueAdd = (netTotal - paidCash).clamp(0, double.infinity);
              final bottleDueAdd = (qty - exchanged).clamp(0, 9999);

              setState(() {
                item['full'] = ((item['full'] as int) - qty).clamp(0, 99999);
                item['empty'] = (item['empty'] as int) + exchanged;
                cashBalance += paidCash;

                final cust = customers[selectedCustomer]!;
                cust['cashDue'] = (cust['cashDue'] as num).toDouble() + cashDueAdd;
                cust['bottleDue'] = (cust['bottleDue'] as int) + bottleDueAdd;
              });
              _saveData();
              Navigator.pop(ctx);
            },
            child: const Text('সেভ করুন'),
          ),
        ],
      ),
    );
  }

  void _openCollectionDialog() {
    String selectedCustomer = customers.keys.first;
    final cashInCtrl = TextEditingController(text: '0');
    final bottleInCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('বকেয়া টাকা ও বোতল আদায়'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedCustomer,
              decoration: const InputDecoration(labelText: 'কাস্টমার'),
              items: customers.keys
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                if (val != null) selectedCustomer = val;
              },
            ),
            TextField(
              controller: cashInCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'আদায়কৃত নগদ টাকা'),
            ),
            TextField(
              controller: bottleInCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ফেরত পাওয়া খালি বোতল'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () {
              final cashIn = double.tryParse(cashInCtrl.text) ?? 0;
              final bottleIn = int.tryParse(bottleInCtrl.text) ?? 0;

              setState(() {
                final cust = customers[selectedCustomer]!;
                final currentCashDue = (cust['cashDue'] as num).toDouble();
                final currentBottleDue = cust['bottleDue'] as int;

                final actualCashCollected = cashIn.clamp(0, currentCashDue).toDouble();
                final actualBottleCollected = bottleIn.clamp(0, currentBottleDue);

                cust['cashDue'] = currentCashDue - actualCashCollected;
                cust['bottleDue'] = currentBottleDue - actualBottleCollected;
                cashBalance += actualCashCollected;
                if (items.isNotEmpty) {
                  items[0]['empty'] = (items[0]['empty'] as int) + actualBottleCollected;
                }
              });
              _saveData();
              Navigator.pop(ctx);
            },
            child: const Text('জমা নিন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalCashDue = 0;
    int totalBottleDue = 0;
    for (final c in customers.values) {
      totalCashDue += (c['cashDue'] as num).toDouble();
      totalBottleDue += c['bottleDue'] as int;
    }

    int totalFull = 0;
    int totalEmpty = 0;
    for (final it in items) {
      totalFull += it['full'] as int;
      totalEmpty += it['empty'] as int;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('গ্যাস ও দোকানের হিসাব'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ক্যাশ ও ব্যালেন্স', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('নগদ হাতে: ${cashBalance.toStringAsFixed(0)} টাকা'),
                  Text('MFS / ব্যাংক: ${(mfsBalance + bankBalance).toStringAsFixed(0)} টাকা'),
                  Text('দোকান অ্যাডভান্স (জামানত): ${shopAdvance.toStringAsFixed(0)} টাকা'),
                  Text('বাকি ঋণ: ${loanPrincipalDue.toStringAsFixed(0)} টাকা'),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('স্টক ও পাওনা সারসংক্ষেপ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('মোট ভরা স্টক: $totalFull | মোট খালি স্টক: $totalEmpty'),
                  Text('কাস্টমারের কাছে মোট টাকা বাকি: ${totalCashDue.toStringAsFixed(0)} টাকা'),
                  Text('কাস্টমারের কাছে মোট খালি বোতল বাকি: $totalBottleDue টি'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openSaleDialog,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('নতুন বিক্রি'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openCollectionDialog,
                  icon: const Icon(Icons.payments),
                  label: const Text('বকেয়া/বোতল আদায়'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('কাস্টমার বাকি খাতা', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ...customers.entries.map((entry) {
            final name = entry.key;
            final due = (entry.value['cashDue'] as num).toDouble();
            final bDue = entry.value['bottleDue'] as int;
            return Card(
              child: ListTile(
                title: Text(name),
                subtitle: Text('টাকা বাকি: ${due.toStringAsFixed(0)} টাকা | বোতল বাকি: $bDue টি'),
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text('পণ্য ও সিলিন্ডার স্টক', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ...items.map((it) {
            return Card(
              child: ListTile(
                title: Text(it['name']),
                subtitle: Text('ভরা: ${it['full']} | খালি: ${it['empty']} | বিক্রয়: ${it['sellPrice']} টাকা'),
              ),
            );
          }),
        ],
      ),
    );
  }
}
