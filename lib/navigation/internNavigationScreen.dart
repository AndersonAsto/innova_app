import 'package:flutter/material.dart';
import 'package:innova/intern/collaboratorsInternScreen.dart';
import 'package:innova/intern/communicationsInternScreen.dart';
import 'package:innova/intern/projectsInternScreen.dart';
import 'package:innova/login/loginScreen.dart';
import 'package:innova/main.dart';
import 'package:sidebarx/sidebarx.dart';

const sidebarCanvasColor        = Color(0xFF022F74);
const sidebarAccentCanvasColor  = Color(0xff1178d5);
const sidebarActionColor        = Color(0xff204760);

class InternNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const InternNavigationScreen({super.key, required this.profile});

  @override
  State<InternNavigationScreen> createState() => _InternNavigationScreenState();
}

class _InternNavigationScreenState extends State<InternNavigationScreen> {
  final SidebarXController _controller = SidebarXController(selectedIndex: 0, extended: true);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _buildLogoutButton({
    required bool extended,
    bool closeDrawer = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.25),
        ),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.logout_rounded,
            color: Colors.red,
            size: 18,
          ),
        ),
        title: extended
            ? const Text(
          'Cerrar sesión',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        )
            : null,
        onTap: () {
          if (closeDrawer) {
            Navigator.pop(context);
          }
          _logout();
        },
      ),
    );
  }

  Widget _buildProfileAvatar() {
    final names = widget.profile['names'] ?? '';
    final surname = widget.profile['fathers_surname'] ?? '';

    final initials =
    '${names.isNotEmpty ? names[0] : ''}'
        '${surname.isNotEmpty ? surname[0] : ''}'
        .toUpperCase();

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF42A5F5),
            Color(0xFF1565C0),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  final List<Widget> pages = [
    ProjectsInternScreen(),
    CollaboratorsInternScreen(),
    CommunicationsInternScreen(),
  ];

  static const List<_NavItem> _items = [
    _NavItem(Icons.bar_chart, 'Proyectos'),
    _NavItem(Icons.groups,    'Colaboradores'),
    _NavItem(Icons.chat,      'Comunicados'),
  ];

  SidebarXTheme get _theme => SidebarXTheme(
    margin: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: sidebarCanvasColor,
      borderRadius: BorderRadius.circular(20),
    ),
    hoverColor: Colors.white.withValues(alpha: 0.1),
    hoverTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 10),
    hoverIconTheme: const IconThemeData(color: Colors.white, size: 20),
    textStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10),
    iconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.7), size: 20),
    selectedTextStyle: const TextStyle(color: Colors.white, fontSize: 10),
    selectedIconTheme: const IconThemeData(color: Colors.white, size: 20),
    selectedItemDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: sidebarActionColor.withValues(alpha: 0.37)),
      gradient: const LinearGradient(colors: [sidebarAccentCanvasColor, sidebarCanvasColor]),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 30)],
    ),
    itemTextPadding: const EdgeInsets.only(left: 16),
    selectedItemTextPadding: const EdgeInsets.only(left: 16),
    itemPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    itemDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: sidebarCanvasColor),
    ),
    padding: EdgeInsets.zero,
  );

  Widget _buildHeader(bool extended) => SizedBox(
    height: 100,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: extended
          ? Row(
              children: [
                _buildProfileAvatar(),
                const SizedBox(width: 5),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          '${widget.profile['names']} ${widget.profile['fathers_surname']}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const Flexible(
                        child: Text('Practicante', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : _buildProfileAvatar(),
    ),
  );

  Widget _buildFooter(bool extended) => ListTile(
    leading: const Icon(Icons.logout, color: Colors.white),
    title: extended ? const Text('Cerrar sesión', style: TextStyle(color: Colors.white)) : null,
    onTap: _logout,
  );

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: sidebarCanvasColor,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildProfileAvatar(),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.profile['names']} ${widget.profile['fathers_surname']}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Practicante',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.3), height: 1),
            const SizedBox(height: 8),
            ...List.generate(_items.length, (i) {
              final item = _items[i];
              return AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  final sel = _controller.selectedIndex == i;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: sel ? BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [sidebarAccentCanvasColor, sidebarCanvasColor],
                      ),
                    ) : null,
                    child: ListTile(
                      leading: Icon(item.icon, color: Colors.white, size: 20),
                      title: Text(item.label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      selected: sel,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onTap: () {
                        _controller.selectIndex(i);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              );
            }),
            const Spacer(),
            Divider(color: Colors.white.withValues(alpha: 0.3), height: 1),
            _buildLogoutButton(
              extended: true,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SidebarX(
              controller: _controller,
              theme: _theme,
              extendedTheme: const SidebarXTheme(
                width: 200,
                decoration: BoxDecoration(color: sidebarCanvasColor),
              ),
              footerDivider: Divider(color: Colors.white.withValues(alpha: 0.3), height: 1),
              headerBuilder: (_, extended) => _buildHeader(extended),
              items: [
                const SidebarXItem(
                  icon: Icons.bar_chart,
                  label: 'Proyectos',
                ),
                const SidebarXItem(
                  icon: Icons.groups,
                  label: 'Colaboradores',
                ),
                const SidebarXItem(
                  icon: Icons.chat,
                  label: 'Comunicados',
                ),
                SidebarXItem(
                  icon: Icons.logout_rounded,
                  label: 'Cerrar sesión',
                  onTap: () {
                    _logout();
                  },
                ),
              ],
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  final index = _controller.selectedIndex;

                  if (index < 0 || index >= pages.length) {
                    return pages[0];
                  }

                  return pages[index];
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildMobileDrawer(),
      appBar: AppBar(
        backgroundColor: sidebarCanvasColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => Text(
            _items[_controller.selectedIndex].label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => pages[_controller.selectedIndex],
      ),
    );
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}