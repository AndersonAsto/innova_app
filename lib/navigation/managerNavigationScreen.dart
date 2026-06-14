import 'package:flutter/material.dart';
import 'package:innova/login/loginScreen.dart';
import 'package:innova/main.dart';
import 'package:innova/manager/communicationsManagerScreen.dart';
import 'package:innova/manager/internsManagerScreen.dart';
import 'package:innova/manager/projectsManagerScreen.dart';
import 'package:sidebarx/sidebarx.dart';

const sidebarCanvasColor        = Color(0xFF022F74);
const sidebarAccentCanvasColor  = Color(0xff1178d5);
const sidebarActionColor        = Color(0xff204760);

class ManagerNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ManagerNavigationScreen({super.key, required this.profile});

  @override
  State<ManagerNavigationScreen> createState() => _ManagerNavigationScreenState();
}

class _ManagerNavigationScreenState extends State<ManagerNavigationScreen> {
  final SidebarXController _controller =
      SidebarXController(selectedIndex: 0, extended: true);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> pages = [
    ProjectsManagerScreen(),
    InternsManagerScreen(),
    CommunicationsManagerScreen(),
  ];

  static const List<_NavItem> _items = [
    _NavItem(Icons.bar_chart,  'Proyectos'),
    _NavItem(Icons.groups,     'Practicantes'),
    _NavItem(Icons.chat,       'Comunicados'),
  ];

  // ─── Sidebar compartido ───────────────────────────────────────────────────
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

  Widget _buildCircularIcon() => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(width: 2, color: Colors.white),
    ),
    child: const Icon(Icons.person, color: Colors.white, size: 28),
  );

  Widget _buildHeader(bool extended) => SizedBox(
    height: 100,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: extended
          ? Row(
              children: [
                _buildCircularIcon(),
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
                      Flexible(
                        child: Text(
                          widget.profile['role'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : _buildCircularIcon(),
    ),
  );

  Widget _buildFooter(bool extended) => ListTile(
    leading: const Icon(Icons.logout, color: Colors.white),
    title: extended ? const Text('Cerrar sesión', style: TextStyle(color: Colors.white)) : null,
    onTap: _logout,
  );

  // ─── Drawer para móvil ────────────────────────────────────────────────────
  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: sidebarCanvasColor,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildCircularIcon(),
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
                          widget.profile['role'] ?? '',
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
            // Items de navegación
            ...List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = _controller.selectedIndex == i;
              return AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  final sel = _controller.selectedIndex == i;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: sel
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              colors: [sidebarAccentCanvasColor, sidebarCanvasColor],
                            ),
                          )
                        : null,
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
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
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
      // ── Layout escritorio: sidebar fijo ──────────────────────────────────
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
              headerDivider: Divider(color: Colors.white.withValues(alpha: 0.3), height: 1),
              footerDivider: Divider(color: Colors.white.withValues(alpha: 0.3), height: 1),
              headerBuilder: (_, extended) => _buildHeader(extended),
              footerBuilder: (_, extended) => _buildFooter(extended),
              items: const [
                SidebarXItem(icon: Icons.bar_chart, label: 'Proyectos'),
                SidebarXItem(icon: Icons.groups,    label: 'Practicantes'),
                SidebarXItem(icon: Icons.chat,      label: 'Comunicados'),
              ],
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => pages[_controller.selectedIndex],
              ),
            ),
          ],
        ),
      );
    }

    // ── Layout móvil: AppBar + Drawer ─────────────────────────────────────
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

// Helper interno
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}