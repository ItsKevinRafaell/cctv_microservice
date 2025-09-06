import 'package:anomeye/features/anomalies/presentation/anomaly_controllers.dart';
import 'package:anomeye/features/anomalies/presentation/widgets/animated_list_item.dart';
import 'package:anomeye/shared/widgets/app_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:anomeye/features/anomalies/presentation/widgets/anomaly_card.dart';
import 'package:go_router/go_router.dart';

class AnomalyHistoryScreen extends ConsumerStatefulWidget {
  const AnomalyHistoryScreen({super.key, this.cameraId});
  final String? cameraId;

  @override
  ConsumerState<AnomalyHistoryScreen> createState() =>
      _AnomalyHistoryScreenState();
}

class _AnomalyHistoryScreenState extends ConsumerState<AnomalyHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Atur bottom nav bar index saat layar ini dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentNavIndexProvider.notifier).state = 1; // 1 untuk History
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(anomaliesListProvider(widget.cameraId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF024670),
          centerTitle: true,
        title: SizedBox(
          height: 50,
          child: Image.asset('assets/images/anomeye.png',fit: BoxFit.contain,),
        ),
          actions: [
            IconButton(onPressed: () => context.push('/settings')
            , icon: const Icon(Icons.settings_outlined),)
          ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(anomaliesListProvider(widget.cameraId).notifier).load(),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No recent alerts found.'),
                  ],
                ),
              );
            }

            // Langsung gunakan ListView.builder tanpa pengelompokan
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final anomaly = items[index];

                // Bungkus setiap AnomalyCard dengan widget animasi
                return AnimatedListItem(
                  index: index,
                  child: AnomalyCard(
                    item: anomaly,
                    onTap: () {
                      context.push('/anomalies/${anomaly.id}');
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}
