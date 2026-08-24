import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura_core/aura_core.dart';
import '../../providers/model_provider.dart';
import '../../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/device_status_bar.dart';
// ignore: unused_import — dipakai di Fase 2 saat ada navigasi langsung ke ChatScreen
import 'chat_screen.dart';


/// Model Manager Screen — First screen the user sees.
/// Detects device RAM, shows available model tiers, and lets user load a model.
class ModelManagerScreen extends ConsumerStatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  ConsumerState<ModelManagerScreen> createState() =>
      _ModelManagerScreenState();
}

class _ModelManagerScreenState extends ConsumerState<ModelManagerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Initialize model detection at startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(modelProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modelState = ref.watch(modelProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(modelState),
              const DeviceStatusBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildRamSection(modelState),
                      const SizedBox(height: 28),
                      _buildModelTiers(modelState),
                      if (modelState.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorBanner(modelState.errorMessage!),
                      ],
                      if (modelState.isLoading) ...[
                        const SizedBox(height: 20),
                        _buildLoadingCard(modelState),
                      ],
                      const SizedBox(height: 28),
                      _buildDetectedModels(modelState),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              if (modelState.isReady) _buildStartChatButton(modelState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.statusError.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.statusError.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.statusError, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.statusError, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ModelState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          // AURA logo mark
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary,
                  AppTheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AURA',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Agentic AI Lokal',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Status indicator
          _StatusDot(status: state.status),
        ],
      ),
    );
  }

  Widget _buildRamSection(ModelState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.memory, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RAM Device',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.deviceRamFormatted,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.secondary.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'Tier ${state.recommendedTier.displayName}',
              style: TextStyle(
                color: AppTheme.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelTiers(ModelState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Model',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilih tier sesuai RAM device. Format kuantisasi: Q4_K_M (standar mobile)',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        ...ModelTier.values.map(
          (tier) => _ModelTierCard(
            tier: tier,
            isRecommended: tier == state.recommendedTier,
            isActive: state.activeModel?.tier == tier,
            state: state,
            onLoad: () => _handleLoadTier(tier, state),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard(ModelState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sedang Memuat Model ke RAM...',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            state.errorMessage ??
                'Menginisialisasi konteks inferensi llama.cpp di latar belakang (non-blocking)...',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              backgroundColor: AppTheme.cardElevated,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedModels(ModelState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Model Terdeteksi',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${state.availableModels.length}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: state.isLoading
                          ? null
                          : () => ref.read(modelProvider.notifier).scanForModels(),
                      icon: const Icon(Icons.refresh, size: 18),
                      color: AppTheme.textMuted,
                      tooltip: 'Pindai Ulang Storage',
                      visualDensity: VisualDensity.compact,
                    ),
                    TextButton.icon(
                      onPressed: state.isLoading ? null : _importModelFile,
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Import (.gguf)', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.availableModels.isEmpty)
          _buildEmptyModelsCard(state)
        else
          ...state.availableModels.map(
            (model) => _ModelFileCard(
              model: model,
              isActive: state.activeModel?.path == model.path,
              isLoading: state.isLoading,
              onTap: () => ref.read(modelProvider.notifier).loadModel(model),
              onEject: () => ref.read(modelProvider.notifier).ejectModel(),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyModelsCard(ModelState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.folder_open, color: AppTheme.textMuted, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Belum Ada Model GGUF',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Impor berkas model .gguf dari penyimpanan HP Anda atau salin ke folder Download.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _importModelFile,
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('Pilih Berkas GGUF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importModelFile() async {
    final success =
        await ref.read(modelProvider.notifier).importModelWithPicker();
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Model GGUF berhasil diimpor ke penyimpanan AURA!'),
          backgroundColor: AppTheme.statusReady,
        ),
      );
    }
  }

  Widget _buildStartChatButton(ModelState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _startChat(state),
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: Text(
            'Mulai Chat dengan ${state.activeModel?.name ?? "Model"}',
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLoadTier(ModelTier tier, ModelState state) async {
    final matchingModel = state.availableModels.cast<GgufModel?>().firstWhere(
          (m) => m?.tier == tier,
          orElse: () => null,
        );

    if (matchingModel != null) {
      await ref.read(modelProvider.notifier).loadModel(matchingModel);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Belum ada file .gguf untuk Tier ${tier.displayName}. '
            'Salin file ke folder Download/Models/ HP Anda.',
          ),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  Future<void> _startChat(ModelState state) async {
    await ref
        .read(chatProvider.notifier)
        .startNewSession(modelName: state.activeModel?.name);

    if (!mounted) return;
    Navigator.of(context).pushNamed('/chat');
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final ModelStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ModelStatus.ready => (AppTheme.statusReady, 'Siap'),
      ModelStatus.loading => (AppTheme.statusLoading, 'Memuat...'),
      ModelStatus.error => (AppTheme.statusError, 'Error'),
      ModelStatus.unloading => (AppTheme.statusLoading, 'Unloading...'),
      ModelStatus.none => (AppTheme.textMuted, 'Idle'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _ModelTierCard extends StatelessWidget {
  const _ModelTierCard({
    required this.tier,
    required this.isRecommended,
    required this.isActive,
    required this.state,
    required this.onLoad,
  });

  final ModelTier tier;
  final bool isRecommended;
  final bool isActive;
  final ModelState state;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive
        ? AppTheme.primary
        : isRecommended
            ? AppTheme.primary.withValues(alpha: 0.4)
            : AppTheme.border;

    return GestureDetector(
      onTap: onLoad,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            _tierIcon(tier),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Tier ${tier.displayName}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Direkomendasikan',
                            style: TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tier.description,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isActive ? Icons.check_circle : Icons.chevron_right,
              color: isActive ? AppTheme.primary : AppTheme.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierIcon(ModelTier t) {
    final (icon, color) = switch (t) {
      ModelTier.light => (Icons.bolt, AppTheme.warning),
      ModelTier.standard => (Icons.balance, AppTheme.secondary),
      ModelTier.advanced => (Icons.rocket_launch, AppTheme.primary),
    };
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _ModelFileCard extends StatelessWidget {
  const _ModelFileCard({
    required this.model,
    required this.isActive,
    required this.isLoading,
    required this.onTap,
    this.onEject,
    super.key,
  });

  final GgufModel model;
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback? onEject;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading || isActive ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              color: isActive ? AppTheme.primary : AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    model.sizeFormatted,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive) ...[
              const Icon(Icons.check_circle, color: AppTheme.statusReady, size: 18),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: isLoading ? null : onEject,
                icon: const Icon(Icons.eject_outlined, size: 14, color: AppTheme.error),
                label: const Text('Lepas', style: TextStyle(color: AppTheme.error, fontSize: 11)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ] else
              Text(
                'Muat',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
