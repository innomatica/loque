import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../helpers/widgets.dart';
import '../../logic/loque.dart';
import '../search/search.dart';

class ChannelsView extends StatefulWidget {
  const ChannelsView({super.key});

  @override
  State<ChannelsView> createState() => _ChannelsViewState();
}

class _ChannelsViewState extends State<ChannelsView> {
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
            : Center(
                child: Icon(Icons.subscriptions_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.surfaceVariant),
              ),
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
