import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/moor_database.dart';
import 'ui/home_page.dart';

void main() => runApp(
    // Wrap with Provider so database wont be created multiple times
    Provider<AppDatabase>(
    create: (context) => AppDatabase(),
    child: MyApp(),
    dispose: (context, db) => db.close()
));

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Bungkus pakai builder supaya bisa akses provider.of
    return Builder(
      builder: (context) {
        final db = Provider.of<AppDatabase>(context);

        return MultiProvider(
          providers: [
            // beda dari ResoCoder, builder sekarang diganti create
            Provider(create: (c) => db.taskDao),
            Provider(create: (c) => db.tagDao),
          ],
          // The single instance of AppDatabase
          // builder: (_) => ,
          // create: (BuildContext context) { return AppDatabase().taskDao; },
          child: MaterialApp(
            title: 'Material App',debugShowCheckedModeBanner: false,
            home: HomePage(),
          ),
        );
      }
    );
  }
}