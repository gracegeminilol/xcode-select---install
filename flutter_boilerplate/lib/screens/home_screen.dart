import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import '../widgets/break_category_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _breaks = [
    ('Thanksgiving Break', Icons.park_outlined, 'Late Nov • 7-10 days'),
    ('Winter Break', Icons.ac_unit, 'Dec-Jan • 1-2 months'),
    ('Spring Break', Icons.flight_takeoff, 'March • 7-10 days'),
    ('Summer Holiday', Icons.wb_sunny_outlined, 'May-Aug • up to 3 months'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Break Sublease'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Profile error: $error')),
        data: (profile) {
          final verificationText = switch (profile?.verificationStatus) {
            null => 'Unverified',
            _ => profile!.verificationStatus.name,
          };

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Verification: $verificationText',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a UIUC break period to quickly filter listings.',
              ),
              const SizedBox(height: 16),
              ..._breaks.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BreakCategoryCard(
                    title: item.$1,
                    subtitle: item.$3,
                    iconData: item.$2,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Filter applied: ${item.$1}')),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
