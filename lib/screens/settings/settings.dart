import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/loque.dart';
import '../../services/sharedprefs.dart';
import '../../settings/constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Widget _buildBody() {
    const titleTextStyle = TextStyle(fontSize: 16.0);
    final menuTextStyle = TextStyle(
      fontSize: 16.0,
      color: Theme.of(context).colorScheme.primary,
    );
    final noteTextStyle = TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.secondary,
    );
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Show episodes from*', style: titleTextStyle),
                const Expanded(child: SizedBox()),
                DropdownButton(
                  value: SharedPrefsService.dataRetentionPeriod,
                  items: dataRetentionPeriodSelection
                      .map<DropdownMenuItem<int>>((e) => DropdownMenuItem<int>(
                            value: e,
                            child: Text('$e days ago', style: menuTextStyle),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      SharedPrefsService.dataRetentionPeriod = value;
                      setState(() {});
                      final logic = context.read<LoqueLogic>();
                      logic.refreshEpisodes();
                    }
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Text('Search engine to use', style: titleTextStyle),
                const Expanded(child: SizedBox()),
                DropdownButton(
                  value: SharedPrefsService.searchEngine,
                  items: searchEngineSelection
                      .map<DropdownMenuItem<String>>(
                          (e) => DropdownMenuItem<String>(
                                value: e,
                                child: Text(e, style: menuTextStyle),
                              ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      SharedPrefsService.searchEngine = value;
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Text('Limit search results to', style: titleTextStyle),
                const Expanded(child: SizedBox()),
                DropdownButton(
                  value: SharedPrefsService.maxSearchResults,
                  items: maxSearchResultsSelection
                      .map<DropdownMenuItem<int>>((e) => DropdownMenuItem<int>(
                            value: e,
                            child: Text('$e items', style: menuTextStyle),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      SharedPrefsService.maxSearchResults = value;
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Text(
              '* Note: episode data store locally will be deleted automatically after 90 days except "liked" ones',
              style: noteTextStyle,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _buildBody(),
    );
  }
}
