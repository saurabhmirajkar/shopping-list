import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shopping_list/data/categories.dart';
import 'package:shopping_list/models/grocery_item.dart';
import 'package:shopping_list/widgets/new_item.dart';
import 'package:http/http.dart' as http;

class GroceryList extends StatefulWidget {
  const GroceryList({super.key});

  @override
  State<GroceryList> createState() => _GroceryListState();
}

class _GroceryListState extends State<GroceryList> {
  final List<GroceryItem> _groceryItems = [];


  late Future<List<GroceryItem>> _loadedItems;

  @override
  void initState() {
    super.initState();
    _loadedItems = _loadItems();
  }

  Future<List<GroceryItem>> _loadItems() async {
    final url = Uri.https('shopping-list-35884-default-rtdb.firebaseio.com',
        'shopping-list.json');

    final response =
        await http.get(url, headers: {'Content-Type': 'authorization/json'});

    if (response.statusCode > 400) {
      throw Exception('Failed to fetch data. Please try again later.');
    }

    if (response.body == 'null') {
      return [];
    }

    final Map<String, dynamic> listData = json.decode(response.body);
    final List<GroceryItem> loadedItems = [];

    for (final item in listData.entries) {
      final category = categories.entries
          .firstWhere((ctg) => item.value['category'] == ctg.value.title)
          .value;

      loadedItems.add(
        GroceryItem(
          id: item.key,
          name: item.value['name'],
          quantity: item.value['quantity'],
          category: category,
        ),
      );
    }

    return loadedItems;
  }

  void _addItem() async {
    final newItem = await Navigator.of(context).push<GroceryItem>(
      MaterialPageRoute(
        builder: (_) => const NewItem(),
      ),
    );

    if (newItem == null) return;

    setState(() {
      _groceryItems.add(newItem);
    });
  }

  void _removeItem(GroceryItem item) async {
    final index = _groceryItems.indexOf(item);
    setState(() {
      _groceryItems.remove(item);
    });

    final url = Uri.https('shopping-list-35884-default-rtdb.firebaseio.com',
        'shopping-list/${item.id}.json');

    final response = await http.delete(url);

    if (response.statusCode > 400) {
      setState(() {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Failed to delete ${item.name}. Please try again later.')));

        _groceryItems.insert(index, item);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Groceries'),
        actions: [
          IconButton(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
          )
        ],
      ),
      body: FutureBuilder(
        future: _loadedItems,
        builder: (context, snapshoot) {
          if (snapshoot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshoot.hasError) {
            return Center(child: Text(snapshoot.error.toString()));
          }

          if (snapshoot.data!.isEmpty) {
            return const Center(child: Text('No items added yet'));
          }

          return ListView.builder(
            itemCount: snapshoot.data!.length,
            itemBuilder: (context, index) {
              return Dismissible(
                key: ValueKey(snapshoot.data![index].id),
                onDismissed: (direction) {
                  _removeItem(snapshoot.data![index]);
                },
                child: ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    color: snapshoot.data![index].category.color,
                  ),
                  title: Text(snapshoot.data![index].name),
                  trailing: Text(snapshoot.data![index].quantity.toString()),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
