import 'package:flutter/material.dart';
import 'package:loqueapp/helpers/widgets.dart';
import 'package:provider/provider.dart';

import '../../logic/loque.dart';
import '../search/search.dart';

class ChannelsView extends StatefulWidget {
  const ChannelsView({super.key});

  @override
  State<ChannelsView> createState() => _ChannelsViewState();
}

class _ChannelsViewState extends State<ChannelsView> {
  Widget _buildInstruction() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'You have no subscriptions',
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16.0),
          const Text(
            'Tap + button and add podcasts, or',
            style: TextStyle(fontSize: 16.0),
          ),
          const SizedBox(height: 16.0),
          Text(
            'Check "How To" from the menu',
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels = context.watch<LoqueLogic>().channels;

    return Stack(
      children: [
        channels.isNotEmpty
            ? GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width ~/ 120,
                mainAxisSpacing: 8.0,
                // childAspectRatio: 0.80,
                children: channels.map((e) => ChannelCard(e)).toList(),
              )
            : _buildInstruction(),
        Positioned(
            right: 20.0,
            bottom: 20.0,
            child: FloatingActionButton(
              child: const Icon(Icons.add_rounded),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SearchPage())),
            )),
      ],
    );
  }
}
