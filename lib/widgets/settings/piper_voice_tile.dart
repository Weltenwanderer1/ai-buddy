import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/buddy_colors.dart';
import '../../services/piper_tts_service.dart';
import 'small_button.dart';

class PiperVoiceTile extends StatelessWidget {
  const PiperVoiceTile({
    super.key,
    required this.voice,
    required this.piper,
    required this.isCurrent,
    required this.onLoad,
    required this.onDelete,
    required this.onDownload,
  });
  final PiperVoice voice;
  final PiperTtsService piper;
  final bool isCurrent;
  final VoidCallback onLoad;
  final VoidCallback onDelete;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return FutureBuilder<bool>(
      future: piper.isVoiceDownloaded(voice),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        final isThisDownloading = piper.isDownloadingVoice(voice);
        final isLoaded = piper.isLoaded && piper.currentVoice == voice;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent
              ? context.buddy.accent.withValues(alpha: 0.15)
              : context.buddy.card.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent
                ? context.buddy.accent.withValues(alpha: 0.5)
                : context.buddy.border,
            ),
          ),
          child: Row(children: [
            Icon(
              isLoaded ? Icons.record_voice_over_rounded
                : isDownloaded ? Icons.download_done_rounded
                : Icons.download_rounded,
              size: 22,
              color: isCurrent ? context.buddy.accent : context.buddy.t2,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(voice.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                    color: isCurrent ? context.buddy.accent : context.buddy.t1,
                  )),
                Text(isThisDownloading
                    ? 'Wird heruntergeladen… ${(piper.downloadProgress * 100).toStringAsFixed(0)}%'
                    : isDownloaded ? 'Heruntergeladen'
                    : 'Nicht heruntergeladen',
                  style: TextStyle(fontSize: 12, color: context.buddy.t3)),
                if (isCurrent) Text(t.config_piper_active,
                  style: TextStyle(fontSize: 11, color: context.buddy.success, fontWeight: FontWeight.w600)),
              ],
            )),
            if (isThisDownloading)
              SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.buddy.accent,
                  backgroundColor: context.buddy.accent.withValues(alpha: 0.2),
                )),
            if (!isThisDownloading) ...[
              if (!isDownloaded)
                SmallButton(
                  icon: Icons.download_rounded,
                  label: t.common_download,
                  onTap: onDownload,
                  color: context.buddy.accent,
                ),
              if (isDownloaded && !isCurrent)
                SmallButton(
                  icon: Icons.play_arrow_rounded,
                  label: t.common_load,
                  onTap: onLoad,
                  color: context.buddy.success,
                ),
              if (isDownloaded && !isCurrent)
                SmallButton(
                  icon: Icons.delete_outline_rounded,
                  label: t.common_delete,
                  onTap: onDelete,
                  color: context.buddy.error,
                ),
            ],
          ]),
        );
      },
    );
  }
}
