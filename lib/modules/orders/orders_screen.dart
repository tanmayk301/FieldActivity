
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';

class OrdersScreen extends StatefulWidget {
  final UserProfile user;

  const OrdersScreen({
    super.key,
    required this.user,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrderLine {
  String? productCode;
  final TextEditingController quantityController =
      TextEditingController();

  void dispose() {
    quantityController.dispose();
  }
}

class _OrdersScreenState extends State<OrdersScreen> {
  final ApiService _api = ApiService();
  final List<_OrderLine> _lines = [_OrderLine()];

  List<EntityRecord> _distributors = [];
  List<Map<String, dynamic>> _products = [];

  String? _selectedDistributorId;
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _api.getEntities('Distributor', widget.user),
        _api.getProducts(),
      ]);

      if (!mounted) return;

      setState(() {
        _distributors = results[0] as List<EntityRecord>;
        _products =
            results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _addProductRow() {
    setState(() {
      _lines.add(_OrderLine());
    });
  }

  void _removeProductRow(int index) {
    if (_lines.length == 1) return;

    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  
List<Map<String, dynamic>> get _availableProducts {
  return _products.where((product) {
    final code = '${product['Product_Code'] ?? ''}';
    return !_lines.any(
      (line) => line.productCode == code,
    );
  }).toList();
}

List<Map<String, dynamic>> _availableProductsFor(
    _OrderLine currentLine) {
  return _products.where((product) {
    final code = '${product['Product_Code'] ?? ''}';

    return !_lines.any(
      (line) =>
          !identical(line, currentLine) &&
          line.productCode == code,
    );
  }).toList();
}


  bool get _isValid {
    if (_selectedDistributorId == null ||
        _lines.isEmpty) {
      return false;
    }

    for (final line in _lines) {
      final quantity =
          int.tryParse(line.quantityController.text);

      if (line.productCode == null ||
          quantity == null ||
          quantity <= 0) {
        return false;
      }
    }

    return true;
  }

  
Future<void> _submitOrder() async {
  if (!_isValid || _submitting) return;

  final distributor = _distributors.firstWhere(
    (d) => d.id == _selectedDistributorId,
  );

  final items = _lines.map((line) {
    final product = _products.firstWhere(
      (p) => '${p['Product_Code']}' == line.productCode,
    );

    return <String, dynamic>{
      'Product_ID': line.productCode,
      'Quantity': int.parse(line.quantityController.text),
      'Unit': 'Units',
    };
  }).toList();

  setState(() => _submitting = true);

  try {
    final result = await _api.submitOrder(
      user: widget.user,
      distributor: distributor,
      items: items,
    );

    if (!mounted) return;

    final orderId = '${result['orderId'] ?? ''}';
    final status = '${result['status'] ?? ''}';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Order submitted'),
        content: Text(
          'Order ID: $orderId\n\n'
          'Status: $status',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    setState(() {
      _selectedDistributorId = null;
      for (final line in _lines) {
        line.dispose();
      }
      _lines
        ..clear()
        ..add(_OrderLine());
    });
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order submission failed: $e'),
        duration: const Duration(seconds: 6),
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _submitting = false);
    }
  }
}


  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distributor Orders'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Unable to load order information.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _loadData();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildOrderForm(),
    );
  }

  Widget _buildOrderForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Created by: ${widget.user.name}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Date: ${DateTime.now().day.toString().padLeft(2, '0')}/'
                  '${DateTime.now().month.toString().padLeft(2, '0')}/'
                  '${DateTime.now().year}',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDistributorId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Distributor *',
                    border: OutlineInputBorder(),
                  ),
                  items: _distributors.map((distributor) {
                    return DropdownMenuItem<String>(
                      value: distributor.id,
                      child: Text(
                        '${distributor.name} (${distributor.id})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDistributorId = value;
                    });
                  },
                ),
                if (_distributors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No distributors were returned by the master.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Products',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _availableProducts.isEmpty
                  ? null
                  : _addProductRow,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_lines.length, (index) {
          final line = _lines[index];
          final available = _availableProductsFor(line);

          return Card(
            key: ObjectKey(line),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Product ${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove product',
                        onPressed: _lines.length > 1
                            ? () => _removeProductRow(index)
                            : null,
                        icon: const Icon(
                          Icons.delete_outline,
                        ),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    value: line.productCode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Product *',
                      border: OutlineInputBorder(),
                    ),
                    items: available.map((product) {
                      final code =
                          '${product['Product_Code']}';
                      final name =
                          '${product['Product_Name']}';

                      return DropdownMenuItem<String>(
                        value: code,
                        child: Text('$name ($code)'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        line.productCode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: line.quantityController,
                    keyboardType:
                        TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
                      hintText: 'Enter quantity',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isValid && !_submitting
    ? _submitOrder
    : null,
            icon: const Icon(Icons.send),
            label: const Text(
              'Submit Order',
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Order submission is not connected yet. '
          'No order will be saved from this screen at this stage.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
