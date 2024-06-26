import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../helpers/logger.dart';
import '../../helpers/widgets.dart';
import '../../logic/github.dart';
import '../../logic/loque.dart';
import '../../settings/constants.dart';
import '../about/about.dart';
import '../settings/settings.dart';
import './playlist.dart';
import 'episodes.dart';
import 'channels.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _sleepTimer;
  int _sleepTimeout = sleepTimeouts[0];
  int _selectedIndex = 0;

  //
  // Scaffold Filter Button
  //
  Widget _buildFilterButton() {
    final logic = context.watch<LoqueLogic>();
    return _selectedIndex == 0
        ? IconButton(
            // visualDensity: VisualDensity.compact,
            icon: logic.filter == EpisodeFilter.unplayed
                ? const Icon(Icons.filter_list_rounded)
                : logic.filter == EpisodeFilter.all
                    ? const Icon(Icons.menu_rounded)
                    : const Icon(Icons.thumb_up_alt_outlined),
            onPressed: () {
              logic.rotateEpisodeFilter();
            },
          )
        : const SizedBox(width: 0, height: 0);
  }

  //
  // Scaffold Menu Button
  //
  Widget _buildMenuButton() {
    return PopupMenuButton<String>(
      icon: Consumer<CartaRepo>(
        builder: (_, repo, __) => repo.newAvailable
            ? Icon(Icons.more_vert, color: Theme.of(context).colorScheme.error)
            : const Icon(Icons.more_vert),
      ),
      onSelected: (String item) {
        if (item == 'Set Sleep Timer') {
          if (_sleepTimer != null) {
            _sleepTimer!.cancel();
            _sleepTimer = null;
          }
          _sleepTimer = Timer.periodic(
            const Duration(minutes: 1),
            (timer) async {
              if (timer.tick == _sleepTimeout) {
                final logic = context.read<LoqueLogic>();
                // timeout
                await logic.stop();
                _sleepTimer!.cancel();
                // is this safe?
                _sleepTimer = null;
              }
              setState(() {});
            },
          );
          setState(() {});
        } else if (item == 'Cancel Sleep Timer') {
          if (_sleepTimer != null) {
            _sleepTimer!.cancel();
            _sleepTimer = null;
          }
          setState(() {});
        } else if (item == 'Settings') {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsPage()));
        } else if (item == 'About') {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => const AboutPage()));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _sleepTimer != null && _sleepTimer!.isActive
              ? "Cancel Sleep Timer"
              : "Set Sleep Timer",
          child: Row(
            children: [
              Icon(Icons.timelapse_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              _sleepTimer != null && _sleepTimer!.isActive
                  ? const Text('Cancel Sleep Timer')
                  : const Text('Set Sleep Timer'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'Settings',
          child: Row(
            children: [
              Icon(Icons.settings_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8.0),
              const Text('Settings'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'About',
          child: Row(
            children: [
              Icon(Icons.info_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8.0),
              Consumer<CartaRepo>(
                builder: (context, repo, child) => repo.newAvailable
                    ? Text('About',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))
                    : const Text('About'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  //
  // Sleep Timer Button
  //
  Widget _buildSleepTimerButton() {
    return TextButton.icon(
      icon: const Icon(Icons.timelapse_rounded),
      label: Text((_sleepTimeout - _sleepTimer!.tick).toString()),
      onPressed: () {
        int index = sleepTimeouts.indexOf(_sleepTimeout);
        index = (index + 1) % sleepTimeouts.length;
        _sleepTimeout = sleepTimeouts[index];
        setState(() {});
      },
    );
  }

  //
  // Body
  //
  Widget _buildBody(BuildContext context) {
    // return _selectedIndex == 1
    //     ? const ChannelsView()
    //     : _selectedIndex == 2
    //         ? const PlayListView()
    //         : const EpisodesView();
    //
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        logDebug('onHorizontalDragEnd:$details');
        final val = details.primaryVelocity ?? 0;
        if (val > swipeGestureThreshold && _selectedIndex > 0) {
          // swipe right
          setState(() {
            _selectedIndex = _selectedIndex - 1;
          });
        } else if (val < -swipeGestureThreshold && _selectedIndex < 2) {
          // swipe left
          setState(() {
            _selectedIndex = _selectedIndex + 1;
          });
        }
      },
      behavior: HitTestBehavior.translucent,
      child: _selectedIndex == 1
          ? const ChannelsView()
          : _selectedIndex == 2
              ? const PlayListView()
              : const EpisodesView(),
    );
  }

  //
  // Bottom Navigation Bar
  //
  Widget _buildBottomNavBar() {
    // return BottomNavigationBar(
    //   onTap: (int index) => setState(() {
    //     _selectedIndex = index;
    //   }),
    //   currentIndex: _selectedIndex,
    //   items: const <BottomNavigationBarItem>[
    //     BottomNavigationBarItem(
    //       icon: Icon(Icons.mic_rounded),
    //       label: 'Episodes',
    //     ),
    //     BottomNavigationBarItem(
    //       icon: Icon(Icons.subscriptions_rounded),
    //       label: 'Subscriptions',
    //     ),
    //     BottomNavigationBarItem(
    //       icon: Icon(Icons.playlist_play_rounded),
    //       label: 'Playlist',
    //     ),
    //   ],
    // );
    return NavigationBar(
      onDestinationSelected: (int index) => setState(() {
        _selectedIndex = index;
      }),
      selectedIndex: _selectedIndex,
      destinations: const <Widget>[
        NavigationDestination(
          icon: Icon(Icons.mic_rounded),
          label: 'Episodes',
        ),
        NavigationDestination(
          icon: Icon(Icons.subscriptions_rounded),
          label: 'Subscriptions',
        ),
        NavigationDestination(
          icon: Icon(Icons.playlist_play_rounded),
          label: 'Playlist',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // logDebug('home.build');
    return Scaffold(
      appBar: AppBar(
        title: const Text("Loque"),
        actions: [
          // timer
          _sleepTimer != null && _sleepTimer!.isActive
              ? _buildSleepTimerButton()
              : Container(),
          // filter button
          _buildFilterButton(),
          // menu button
          _buildMenuButton(),
          const SizedBox(width: 4.0),
        ],
      ),
      body: _buildBody(context),
      // https://github.com/flutter/flutter/issues/50314
      // bottomSheet: buildMiniPlayer(context),
      // bottomNavigationBar: _buildBottomNavBar(),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildMiniPlayer(context),
          _buildBottomNavBar(),
        ],
      ),
    );
  }
}
