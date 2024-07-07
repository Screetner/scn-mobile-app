import 'package:flutter/material.dart';

import '../page/HomePage.dart';
import '../page/MessagePage.dart';
import '../page/NotificationPage.dart';
import '../page/RecordPage.dart';

class ScreetnerMainApp extends StatelessWidget {
  const ScreetnerMainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const ScreetnerHome(),
    );
  }
}

class ScreetnerHome extends StatefulWidget {
  const ScreetnerHome({super.key});

  @override
  State<ScreetnerHome> createState() => _ScreetnerHomeState();
}

class _ScreetnerHomeState extends State<ScreetnerHome> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: <Widget>[
        HomePage(),
        NotificationPage(),
        MessagePage(),
      ][currentPageIndex],
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          if(index == 1) { // record Page
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RecordPage()),
            );

            return;
          }
          setState(() {
            currentPageIndex = index;
          });
        },
        indicatorColor: Colors.green,
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home_outlined),
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.videocam_sharp),
            icon: Badge(child: Icon(Icons.videocam_sharp)),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('2'),
              child: Icon(Icons.list),
            ),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
