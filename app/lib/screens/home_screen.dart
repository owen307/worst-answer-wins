import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game_controller.dart';
import '../party_widgets.dart';
import '../server_url.dart';
import '../theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final GameController controller;

  Future<void> _openHost(BuildContext context) {
    controller.clearError();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HostSheet(controller: controller),
    ).whenComplete(controller.abandonAttempt);
  }

  Future<void> _openJoin(BuildContext context) {
    controller.clearError();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _JoinSheet(controller: controller),
    ).whenComplete(controller.abandonAttempt);
  }

  @override
  Widget build(BuildContext context) {
    return PartyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: PartyMark()),
                      const SizedBox(height: 18),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Worst Answer Wins',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            height: 0.95,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Write the worst answer. Steal the points.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 28),
                      PartyButton(
                        label: 'Host a party',
                        onPressed: () => _openHost(context),
                      ),
                      const SizedBox(height: 12),
                      PartyButton(
                        label: 'Join with a code',
                        color: PartyColors.mint,
                        foreground: PartyColors.ink,
                        onPressed: () => _openJoin(context),
                      ),
                      const SizedBox(height: 22),
                      _ServerCard(controller: controller),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ServerCard extends StatefulWidget {
  const _ServerCard({required this.controller});

  final GameController controller;

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  late final TextEditingController _text = TextEditingController(
    text: widget.controller.serverUrl,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFromController);
  }

  void _syncFromController() {
    final next = widget.controller.serverUrl;
    if (next != _text.text && next == normalizeServerUrl(_text.text)) {
      _text.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PartyColors.ink, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Server',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('server-url'),
            controller: _text,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'ws://192.168.1.20:8787',
            ),
            onChanged: widget.controller.updateServerUrl,
          ),
          const SizedBox(height: 8),
          const Text(
            'Phones on the same Wi-Fi use your computer, like ws://192.168.1.20:8787. The Android emulator can use ws://10.0.2.2:8787.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: PartyColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: PartyColors.ink, width: 3),
            left: BorderSide(color: PartyColors.ink, width: 3),
            right: BorderSide(color: PartyColors.ink, width: 3),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _HostSheet extends StatefulWidget {
  const _HostSheet({required this.controller});

  final GameController controller;

  @override
  State<_HostSheet> createState() => _HostSheetState();
}

class _HostSheetState extends State<_HostSheet> {
  final _name = TextEditingController();
  int _rounds = 5;
  String? _localError;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
  }

  void _onController() {
    if (!mounted) return;
    if (widget.controller.room != null) {
      widget.controller.removeListener(_onController);
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final nameError = validateName(_name.text);
    final serverError = validateServerUrl(widget.controller.serverUrl);
    setState(() => _localError = nameError ?? serverError);
    if (_localError != null) return;
    widget.controller.createRoom(name: _name.text, rounds: _rounds);
  }

  @override
  Widget build(BuildContext context) {
    final error = _localError ?? widget.controller.error;
    return _SheetFrame(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Grabber(),
            const Text(
              'Host a party',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '2–8 players. Three or more is the sweet spot. You play too.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('host-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              maxLength: 16,
              decoration: const InputDecoration(
                labelText: 'Your name',
                hintText: 'Ava',
                counterText: '',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            const Text(
              'How many rounds?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final rounds in [3, 5, 7]) ...[
                  if (rounds != 3) const SizedBox(width: 8),
                  Expanded(
                    child: _RoundChoice(
                      label: '$rounds',
                      selected: _rounds == rounds,
                      onTap: () => setState(() => _rounds = rounds),
                    ),
                  ),
                ],
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              ErrorNote(message: error),
            ],
            const SizedBox(height: 16),
            PartyButton(
              label: 'Open the room',
              busy: widget.controller.connecting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinSheet extends StatefulWidget {
  const _JoinSheet({required this.controller});

  final GameController controller;

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  String? _localError;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
  }

  void _onController() {
    if (!mounted) return;
    if (widget.controller.room != null) {
      widget.controller.removeListener(_onController);
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final nameError = validateName(_name.text);
    final serverError = validateServerUrl(widget.controller.serverUrl);
    String? codeError;
    if (_code.text.trim().length < 4) {
      codeError = 'Enter the 4-letter room code.';
    }
    setState(() => _localError = nameError ?? codeError ?? serverError);
    if (_localError != null) return;
    widget.controller.joinRoom(code: _code.text, name: _name.text);
  }

  @override
  Widget build(BuildContext context) {
    final error = _localError ?? widget.controller.error;
    return _SheetFrame(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Grabber(),
            const Text(
              'Join a party',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ask the host for the code on their screen.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('join-code'),
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                labelText: 'Room code',
                hintText: 'GRAB',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('join-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 16,
              decoration: const InputDecoration(
                labelText: 'Your name',
                hintText: 'Noah',
                counterText: '',
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              ErrorNote(message: error),
            ],
            const SizedBox(height: 16),
            PartyButton(
              label: 'Hop in',
              color: PartyColors.mint,
              foreground: PartyColors.ink,
              busy: widget.controller.connecting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundChoice extends StatelessWidget {
  const _RoundChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PartyColors.sun : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: PartyColors.ink, width: 3),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 64,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48,
        height: 6,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: PartyColors.ink.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
