import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'mock_data.dart';

class DatabaseService {
  // Check if Firebase is initialized and available
  static bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  // ==================== NUMBER NORMALIZATION ====================
  // Firestore (especially on Flutter Web) can round-trip a whole-number
  // double (e.g. 500.0) back as an int. Any hard `as double` / `as int`
  // cast downstream then throws a TypeError, which silently breaks
  // widget rendering (this is why expenses could be added successfully
  // but never show up). These helpers normalize the type on every read
  // so the rest of the app can always rely on the expected type.
  static double _asDouble(dynamic value, [double fallback = 0.0]) {
    if (value is num) return value.toDouble();
    return fallback;
  }

  static int _asInt(dynamic value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return fallback;
  }

  static Map<String, dynamic> _normalizeItem(Map<String, dynamic> data) {
    data['quantity'] = _asInt(data['quantity']);
    data['price'] = _asDouble(data['price']);
    data['lowStockThreshold'] = _asInt(data['lowStockThreshold']);
    return data;
  }

  static Map<String, dynamic> _normalizeExpense(Map<String, dynamic> data) {
    data['amount'] = _asDouble(data['amount']);
    return data;
  }

  static Map<String, dynamic> _normalizeIncome(Map<String, dynamic> data) {
    data['amount'] = _asDouble(data['amount']);
    return data;
  }

  // ==================== INVENTORY/PRODUCTS ====================

  static Stream<List<Map<String, dynamic>>> streamItems() {
    if (isFirebaseInitialized) {
      try {
        return FirebaseFirestore.instance.collection('products').snapshots().map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            if (data['lastUpdated'] is Timestamp) {
              data['lastUpdated'] = (data['lastUpdated'] as Timestamp).toDate();
            }
            return _normalizeItem(data);
          }).toList();
        });
      } catch (e) {
        debugPrint('Firestore streamItems error: $e. Falling back to mock stream.');
      }
    }

    return Stream<List<Map<String, dynamic>>>.value(
      List<Map<String, dynamic>>.from(
        MockData.inventoryItems.map((item) => _normalizeItem(Map<String, dynamic>.from(item))),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getItems() async {
    if (isFirebaseInitialized) {
      try {
        final querySnapshot = await FirebaseFirestore.instance.collection('products').get();
        return querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          if (data['lastUpdated'] is Timestamp) {
            data['lastUpdated'] = (data['lastUpdated'] as Timestamp).toDate();
          }
          return _normalizeItem(data);
        }).toList();
      } catch (e) {
        debugPrint('Firestore getItems error: $e. Falling back to mock data.');
      }
    }
    // Fallback to local copy
    return List<Map<String, dynamic>>.from(
      MockData.inventoryItems.map((item) => _normalizeItem(Map<String, dynamic>.from(item))),
    );
  }

  static Future<void> addItem(Map<String, dynamic> item) async {
    if (isFirebaseInitialized) {
      try {
        final String id = item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        item['id'] = id;
        
        final writeData = Map<String, dynamic>.from(item);
        if (writeData['lastUpdated'] is DateTime) {
          writeData['lastUpdated'] = Timestamp.fromDate(writeData['lastUpdated'] as DateTime);
        } else {
          writeData['lastUpdated'] = FieldValue.serverTimestamp();
        }
        
        await FirebaseFirestore.instance.collection('products').doc(id).set(writeData);
        return;
      } catch (e) {
        debugPrint('Firestore addItem error: $e. Saving locally.');
      }
    }
    
    // Offline Mock Fallback
    if (item['lastUpdated'] is! DateTime) {
      item['lastUpdated'] = DateTime.now();
    }
    // Check if item already exists locally to avoid duplication
    final index = MockData.inventoryItems.indexWhere((i) => i['id'] == item['id'] || (item['barcode'] != null && i['barcode'] == item['barcode']));
    if (index != -1) {
      MockData.inventoryItems[index] = item;
    } else {
      MockData.inventoryItems.add(item);
    }
  }

  static Future<void> updateItem(Map<String, dynamic> item) async {
    if (isFirebaseInitialized) {
      try {
        final id = item['id'];
        final writeData = Map<String, dynamic>.from(item);
        if (writeData['lastUpdated'] is DateTime) {
          writeData['lastUpdated'] = Timestamp.fromDate(writeData['lastUpdated'] as DateTime);
        } else {
          writeData['lastUpdated'] = FieldValue.serverTimestamp();
        }
        
        await FirebaseFirestore.instance.collection('products').doc(id).update(writeData);
        return;
      } catch (e) {
        debugPrint('Firestore updateItem error: $e. Updating locally.');
      }
    }
    
    // Offline Mock Fallback
    if (item['lastUpdated'] is! DateTime) {
      item['lastUpdated'] = DateTime.now();
    }
    final index = MockData.inventoryItems.indexWhere((i) => i['id'] == item['id']);
    if (index != -1) {
      MockData.inventoryItems[index] = item;
    }
  }

  static Future<void> deleteItem(String id) async {
    if (isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance.collection('products').doc(id).delete();
        return;
      } catch (e) {
        debugPrint('Firestore deleteItem error: $e. Deleting locally.');
      }
    }
    
    // Offline Mock Fallback
    MockData.inventoryItems.removeWhere((i) => i['id'] == id);
  }

  // ==================== EXPENSES ====================

  static Stream<List<Map<String, dynamic>>> streamExpenses() {
    if (isFirebaseInitialized) {
      try {
        return FirebaseFirestore.instance.collection('expenses').snapshots().map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            if (data['date'] is Timestamp) {
              data['date'] = (data['date'] as Timestamp).toDate();
            }
            if (data['colorHex'] != null) {
              final hex = data['colorHex'] as String;
              data['color'] = Color(int.parse(hex, radix: 16));
            } else {
              data['color'] = const Color(0xFF667eea);
            }
            return _normalizeExpense(data);
          }).toList();
        });
      } catch (e) {
        debugPrint('Firestore streamExpenses error: $e. Falling back to mock stream.');
      }
    }

    return Stream<List<Map<String, dynamic>>>.value(
      List<Map<String, dynamic>>.from(
        MockData.expenses.map((expense) => _normalizeExpense(Map<String, dynamic>.from(expense))),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getExpenses() async {
    if (isFirebaseInitialized) {
      try {
        final querySnapshot = await FirebaseFirestore.instance.collection('expenses').get();
        return querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          if (data['date'] is Timestamp) {
            data['date'] = (data['date'] as Timestamp).toDate();
          }
          if (data['colorHex'] != null) {
            final hex = data['colorHex'] as String;
            data['color'] = Color(int.parse(hex, radix: 16));
          } else {
            data['color'] = const Color(0xFF667eea);
          }
          return _normalizeExpense(data);
        }).toList();
      } catch (e) {
        debugPrint('Firestore getExpenses error: $e. Falling back to mock data.');
      }
    }
    // Fallback to local copy
    return List<Map<String, dynamic>>.from(
      MockData.expenses.map((expense) => _normalizeExpense(Map<String, dynamic>.from(expense))),
    );
  }

  static Future<void> addExpense(Map<String, dynamic> expense) async {
    if (isFirebaseInitialized) {
      try {
        final String id = expense['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        expense['id'] = id;
        
        final writeData = Map<String, dynamic>.from(expense);
        if (writeData['date'] is DateTime) {
          writeData['date'] = Timestamp.fromDate(writeData['date'] as DateTime);
        }
        writeData.remove('color'); // Remove Color class before writing to Firestore
        
        await FirebaseFirestore.instance.collection('expenses').doc(id).set(writeData);
        return;
      } catch (e) {
        debugPrint('Firestore addExpense error: $e. Saving locally.');
      }
    }
    
    // Offline Mock Fallback
    if (expense['date'] is Timestamp) {
      expense['date'] = (expense['date'] as Timestamp).toDate();
    }
    if (expense['color'] == null && expense['colorHex'] != null) {
      expense['color'] = Color(int.parse(expense['colorHex']!, radix: 16));
    }
    MockData.expenses.add(expense);
  }

  static Future<void> updateExpense(Map<String, dynamic> expense) async {
    if (isFirebaseInitialized) {
      try {
        final id = expense['id'];
        final writeData = Map<String, dynamic>.from(expense);
        if (writeData['date'] is DateTime) {
          writeData['date'] = Timestamp.fromDate(writeData['date'] as DateTime);
        }
        writeData.remove('color'); // Remove Color class before writing to Firestore
        
        await FirebaseFirestore.instance.collection('expenses').doc(id).update(writeData);
        return;
      } catch (e) {
        debugPrint('Firestore updateExpense error: $e. Updating locally.');
      }
    }
    
    // Offline Mock Fallback
    if (expense['date'] is Timestamp) {
      expense['date'] = (expense['date'] as Timestamp).toDate();
    }
    if (expense['color'] == null && expense['colorHex'] != null) {
      expense['color'] = Color(int.parse(expense['colorHex']!, radix: 16));
    }
    final index = MockData.expenses.indexWhere((e) => e['id'] == expense['id']);
    if (index != -1) {
      MockData.expenses[index] = expense;
    }
  }

  static Future<void> deleteExpense(String id) async {
    if (isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance.collection('expenses').doc(id).delete();
        return;
      } catch (e) {
        debugPrint('Firestore deleteExpense error: $e. Deleting locally.');
      }
    }
    
    // Offline Mock Fallback
    MockData.expenses.removeWhere((e) => e['id'] == id);
  }

  // ==================== INCOME ====================
  // Mirrors the Expenses section above. Every successful sale (manual Sell
  // Item screen or barcode "Scan to Sell") logs a transaction here, and this
  // also supports manually-added income (e.g. investment, service revenue).

  static Stream<List<Map<String, dynamic>>> streamIncome() {
    if (isFirebaseInitialized) {
      try {
        return FirebaseFirestore.instance.collection('income').snapshots().map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            if (data['date'] is Timestamp) {
              data['date'] = (data['date'] as Timestamp).toDate();
            }
            if (data['colorHex'] != null) {
              final hex = data['colorHex'] as String;
              data['color'] = Color(int.parse(hex, radix: 16));
            } else {
              data['color'] = const Color(0xFF66bb6a);
            }
            return _normalizeIncome(data);
          }).toList();
        });
      } catch (e) {
        debugPrint('Firestore streamIncome error: $e. Falling back to mock stream.');
      }
    }

    return Stream<List<Map<String, dynamic>>>.value(
      List<Map<String, dynamic>>.from(
        MockData.income.map((income) => _normalizeIncome(Map<String, dynamic>.from(income))),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getIncome() async {
    if (isFirebaseInitialized) {
      try {
        final querySnapshot = await FirebaseFirestore.instance.collection('income').get();
        return querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          if (data['date'] is Timestamp) {
            data['date'] = (data['date'] as Timestamp).toDate();
          }
          if (data['colorHex'] != null) {
            final hex = data['colorHex'] as String;
            data['color'] = Color(int.parse(hex, radix: 16));
          } else {
            data['color'] = const Color(0xFF66bb6a);
          }
          return _normalizeIncome(data);
        }).toList();
      } catch (e) {
        debugPrint('Firestore getIncome error: $e. Falling back to mock data.');
      }
    }
    return List<Map<String, dynamic>>.from(
      MockData.income.map((income) => _normalizeIncome(Map<String, dynamic>.from(income))),
    );
  }

  static Future<void> addIncome(Map<String, dynamic> income) async {
    if (isFirebaseInitialized) {
      try {
        final String id = income['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        income['id'] = id;

        final writeData = Map<String, dynamic>.from(income);
        if (writeData['date'] is DateTime) {
          writeData['date'] = Timestamp.fromDate(writeData['date'] as DateTime);
        }
        writeData.remove('color'); // Remove Color class before writing to Firestore

        await FirebaseFirestore.instance.collection('income').doc(id).set(writeData);
        return;
      } catch (e) {
        debugPrint('Firestore addIncome error: $e. Saving locally.');
      }
    }

    // Offline Mock Fallback
    if (income['date'] is Timestamp) {
      income['date'] = (income['date'] as Timestamp).toDate();
    }
    if (income['color'] == null && income['colorHex'] != null) {
      income['color'] = Color(int.parse(income['colorHex']!, radix: 16));
    }
    MockData.income.add(income);
  }

  static Future<void> updateIncome(Map<String, dynamic> income) async {
    if (isFirebaseInitialized) {
      try {
        final id = income['id'];
        final writeData = Map<String, dynamic>.from(income);
        if (writeData['date'] is DateTime) {
          writeData['date'] = Timestamp.fromDate(writeData['date'] as DateTime);
        }
        writeData.remove('color');

        await FirebaseFirestore.instance.collection('income').doc(id).update(writeData);
        return;
      } catch (e) {
        debugPrint('Firestore updateIncome error: $e. Updating locally.');
      }
    }

    // Offline Mock Fallback
    if (income['date'] is Timestamp) {
      income['date'] = (income['date'] as Timestamp).toDate();
    }
    if (income['color'] == null && income['colorHex'] != null) {
      income['color'] = Color(int.parse(income['colorHex']!, radix: 16));
    }
    final index = MockData.income.indexWhere((i) => i['id'] == income['id']);
    if (index != -1) {
      MockData.income[index] = income;
    }
  }

  static Future<void> deleteIncome(String id) async {
    if (isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance.collection('income').doc(id).delete();
        return;
      } catch (e) {
        debugPrint('Firestore deleteIncome error: $e. Deleting locally.');
      }
    }

    // Offline Mock Fallback
    MockData.income.removeWhere((i) => i['id'] == id);
  }
}