import 'package:cell_forensic/features/session/session_view_model.dart';
import 'package:flutter/material.dart';

/// Minimal UI shell for the session feature.
///
/// Intentionally lightweight: it renders the [SessionViewModel] state and wires
/// a join field. Feature logic lives in the view model and repository, keeping
/// this widget a thin presentation layer.
class SessionScreen extends StatefulWidget {
  const SessionScreen({required this.viewModel, super.key});

  final SessionViewModel viewModel;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final TextEditingController _joinCodeController = TextEditingController();

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        final state = widget.viewModel.state;
        return Scaffold(
          appBar: AppBar(title: const Text('Gabung Sesi')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _joinCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode Gabung',
                    hintText: 'mis. ABC123',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: state.isBusy
                      ? null
                      : () => widget.viewModel.join(_joinCodeController.text),
                  child: const Text('Gabung'),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.error!.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (state.isJoined) ...[
                  const SizedBox(height: 16),
                  Text('Sesi aktif: ${state.session!.joinCode}'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.groups.length,
                      itemBuilder: (context, index) {
                        final group = state.groups[index];
                        final leader = group.members
                            .where((m) => m.isLeader)
                            .map((m) => m.displayName)
                            .join();
                        return ListTile(
                          title: Text(group.name),
                          subtitle: Text(
                            'Ketua: $leader • Anggota: ${group.members.length}',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
