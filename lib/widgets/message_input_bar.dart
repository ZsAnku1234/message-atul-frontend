import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/app_providers.dart';
import '../theme/color_tokens.dart';

class MessageInputBar extends ConsumerStatefulWidget {
  const MessageInputBar({
    super.key,
    required this.onSend,
    this.isSending = false,
    this.isEnabled = true,
  });

  final Future<void> Function(String text, List<String> attachments) onSend;
  final bool isSending;
  final bool isEnabled;

  @override
  ConsumerState<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends ConsumerState<MessageInputBar> {
  static const int _maxAttachments = 50;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  final List<_AttachmentDraft> _attachments = [];

  int _draftSeed = 0;

  bool get _hasUploadingAttachments =>
      _attachments.any((draft) => draft.status == _AttachmentStatus.uploading);

  bool get _canAddMoreAttachments =>
      widget.isEnabled &&
      !_hasUploadingAttachments &&
      _attachments.length < _maxAttachments;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    final readyAttachments = _attachments
        .where(
          (draft) =>
              draft.status == _AttachmentStatus.ready && draft.url != null,
        )
        .map((draft) => draft.url!)
        .toList();

    if (text.isEmpty && readyAttachments.isEmpty) {
      return;
    }

    if (widget.isSending || _hasUploadingAttachments || !widget.isEnabled) {
      return;
    }

    final previousDrafts = List<_AttachmentDraft>.from(_attachments);

    _controller.clear();

    try {
      await widget.onSend(text, readyAttachments);
      if (!mounted) return;
      setState(() {
        _attachments
          ..clear()
          ..addAll(previousDrafts
              .where((draft) => draft.status == _AttachmentStatus.error));
      });
      _focusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _attachments
          ..clear()
          ..addAll(previousDrafts);
      });
      _controller
        ..text = text
        ..selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
    }
  }

  Future<void> _openAttachmentSheet() async {
    if (!_canAddMoreAttachments) {
      _showError('You can add up to $_maxAttachments attachments per message.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AttachmentActionTile(
                icon: Icons.camera_alt_outlined,
                label: 'Take Photo',
                onTap: () {
                  Navigator.of(context).pop();
                  _capturePhoto();
                },
              ),
              _AttachmentActionTile(
                icon: Icons.photo_library_outlined,
                label: 'Photo Library',
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImages();
                },
              ),
              _AttachmentActionTile(
                icon: Icons.videocam_outlined,
                label: 'Record Video',
                onTap: () {
                  Navigator.of(context).pop();
                  _captureVideo();
                },
              ),
              _AttachmentActionTile(
                icon: Icons.video_library_outlined,
                label: 'Video Library',
                onTap: () {
                  Navigator.of(context).pop();
                  _pickVideo();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _capturePhoto() async {
    if (!_canAddMoreAttachments) {
      _showError('Attachment limit reached.');
      return;
    }
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo != null) {
      await _uploadAttachments([photo], _AttachmentType.image);
    }
  }

  Future<void> _pickImages() async {
    if (!_canAddMoreAttachments) {
      _showError('Attachment limit reached.');
      return;
    }
    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;
    await _uploadAttachments(images, _AttachmentType.image);
  }

  Future<void> _captureVideo() async {
    if (!_canAddMoreAttachments) {
      _showError('Attachment limit reached.');
      return;
    }
    final video = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 2),
    );
    if (video != null) {
      await _uploadAttachments([video], _AttachmentType.video);
    }
  }

  Future<void> _pickVideo() async {
    if (!_canAddMoreAttachments) {
      _showError('Attachment limit reached.');
      return;
    }
    // Using pickMultipleMedia to allow selecting multiple videos
    final medias = await _picker.pickMultipleMedia(
      limit: _maxAttachments - _attachments.length,
    );
    
    if (medias.isEmpty) return;

    // Filter to keep mostly videos if possible, or just upload all
    // Since pickMultipleMedia returns both images and videos, we'll just accept them.
    await _uploadAttachments(medias, _AttachmentType.video);
  }

  Future<void> _uploadAttachments(
    List<XFile> files,
    _AttachmentType typeHint,
  ) async {
    final remaining = _maxAttachments - _attachments.length;
    final limitedFiles = files.take(remaining).toList();
    if (limitedFiles.isEmpty) {
      _showError('You can only attach $_maxAttachments items per message.');
      return;
    }

    final placeholders = limitedFiles
        .map(
          (_) => _AttachmentDraft(
            id: _nextDraftId(),
            type: typeHint,
            status: _AttachmentStatus.uploading,
          ),
        )
        .toList();

    setState(() {
      _attachments.addAll(placeholders);
    });

    try {
      final repository = ref.read(mediaRepositoryProvider);
      final uploads = await repository.uploadMedia(limitedFiles);

      if (uploads.length != placeholders.length) {
        throw StateError('Upload response mismatch');
      }

      if (!mounted) return;

      setState(() {
        final startIndex = _attachments.length - placeholders.length;
        _attachments.replaceRange(
          startIndex,
          _attachments.length,
          List.generate(placeholders.length, (index) {
            final upload = uploads[index];
            final resolvedType = upload.isVideo
                ? _AttachmentType.video
                : (upload.isImage
                    ? _AttachmentType.image
                    : placeholders[index].type);
            return placeholders[index].copyWith(
              url: upload.url,
              type: resolvedType,
              status: _AttachmentStatus.ready,
            );
          }),
        );
      });
    } catch (_) {
      if (!mounted) return;
      _showError('Failed to upload media. Please try again.');
      setState(() {
        for (final draft in placeholders) {
          final index = _attachments.indexWhere((item) => item.id == draft.id);
          if (index >= 0) {
            _attachments[index] =
                draft.copyWith(status: _AttachmentStatus.error);
          }
        }
      });
    }
  }

  void _removeAttachment(String id) {
    setState(() {
      _attachments.removeWhere((draft) => draft.id == id);
    });
  }

  String _nextDraftId() {
    _draftSeed += 1;
    return 'draft_${DateTime.now().microsecondsSinceEpoch}_$_draftSeed';
  }

  void _showError(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.isSending || _hasUploadingAttachments;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: Offset(0, -4),
              color: Color(0x11000000),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _attachments
                      .map(
                        (draft) => _AttachmentPreview(
                          draft: draft,
                          onRemove: () => _removeAttachment(draft.id),
                        ),
                      )
                      .toList(),
                ),
              ),
            Opacity(
              opacity: widget.isEnabled ? 1 : 0.5,
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.isEnabled && !_hasUploadingAttachments
                        ? _openAttachmentSheet
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        readOnly: !widget.isEnabled,
                        enabled: widget.isEnabled,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: const InputDecoration(
                          hintText: 'Write a message...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: isBusy || !widget.isEnabled ? null : _submit,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.linearGradient,
                      ),
                      child: isBusy
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentActionTile extends StatelessWidget {
  const _AttachmentActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}

enum _AttachmentType { image, video }

enum _AttachmentStatus { uploading, ready, error }

class _AttachmentDraft {
  const _AttachmentDraft({
    required this.id,
    required this.type,
    required this.status,
    this.url,
  });

  final String id;
  final _AttachmentType type;
  final _AttachmentStatus status;
  final String? url;

  _AttachmentDraft copyWith({
    _AttachmentType? type,
    _AttachmentStatus? status,
    String? url,
  }) {
    return _AttachmentDraft(
      id: id,
      type: type ?? this.type,
      status: status ?? this.status,
      url: url ?? this.url,
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.draft,
    required this.onRemove,
  });

  final _AttachmentDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isVideo = draft.type == _AttachmentType.video;
    final isUploading = draft.status == _AttachmentStatus.uploading;
    final isError = draft.status == _AttachmentStatus.error;

    final borderColor = isError ? AppColors.danger : Colors.transparent;

    return Stack(
      children: [
        Container(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.4),
            color: Colors.grey.shade200,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildContent(isUploading, isError),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.cancel_rounded,
              size: 20,
              color: Colors.black54,
            ),
            splashRadius: 18,
          ),
        ),
        if (isVideo)
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(bool isUploading, bool isError) {
    if (isUploading) {
      return const Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (isError) {
      return const Center(
        child: Icon(Icons.error_outline, color: AppColors.danger),
      );
    }

    if (draft.url != null) {
      return Image.network(
        draft.url!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined),
        ),
      );
    }

    return const ColoredBox(
      color: Color(0xFFD9DCE2),
    );
  }
}
