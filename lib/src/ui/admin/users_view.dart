part of 'admin_screens.dart';

class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  List<User> _users = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await widget.controller.api.getUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrEdit([User? user]) async {
    final result = await showDialog<JsonMap>(
      context: context,
      builder: (context) => UserDialog(user: user),
    );
    if (result == null) return;
    try {
      if (user == null) {
        await widget.controller.api.createUser(result);
      } else {
        await widget.controller.api.updateUser(user.id, result);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _delete(User user) async {
    final ok = await confirmDialog(context, 'Xóa tài khoản ${user.email}?');
    if (!ok) return;
    try {
      await widget.controller.api.deleteUser(user.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionTitle(
            'Tài khoản (${_users.length})',
            action: IconButton.filled(
              tooltip: 'Tạo tài khoản',
              onPressed: () => _createOrEdit(),
              icon: const Icon(Icons.add),
            ),
          ),
          if (_users.isEmpty)
            const EmptyState('Chưa có tài khoản')
          else
            ..._users.map(
              (user) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(user.id.toString())),
                  title: Text(user.fullName),
                  subtitle: Text('${user.email}\n${user.role}'),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Sửa',
                        onPressed: () => _createOrEdit(user),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: 'Xóa',
                        onPressed: () => _delete(user),
                        icon: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
