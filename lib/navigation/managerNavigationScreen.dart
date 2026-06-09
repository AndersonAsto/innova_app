import 'package:flutter/material.dart';
import 'package:innova/manager/communicationsManagerScreen.dart';
import 'package:innova/manager/internsManagerScreen.dart';
import 'package:innova/manager/projectsManagerScreen.dart';
import 'package:sidebarx/sidebarx.dart';

const sidebarCanvasColor = Color(0xFF022F74);
const sidebarAccentCanvasColor = Color(0xff1178d5);
const sidebarActionColor = Color(0xff204760);
final sidebarDivider = Divider(color: Colors.white.withOpacity(0.3), height: 1);

class ManagerNavigationScreen extends StatefulWidget {
  const ManagerNavigationScreen({super.key});

  @override
  State<ManagerNavigationScreen> createState() => _ManagerNavigationScreenState();
}

class _ManagerNavigationScreenState extends State<ManagerNavigationScreen> {
  Widget buildCircularIcon() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(width: 2, color: Colors.white),
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 28),
    );
  }

  final SidebarXController _controller = SidebarXController(selectedIndex: 0, extended: true);

  final List<Widget> pages = [
    ProjectsManagerScreen(),
    InternsManagerScreen(),
    CommunicationsManagerScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SidebarX(
            controller: _controller,
            theme: SidebarXTheme(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: sidebarCanvasColor,
                borderRadius: BorderRadius.circular(20),
              ),
              hoverColor: Colors.white.withOpacity(0.1),
              hoverTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
              hoverIconTheme: const IconThemeData(
                color: Colors.white,
                size: 20,
              ),
              textStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
              iconTheme: IconThemeData(
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
              selectedTextStyle: const TextStyle(color: Colors.white),
              selectedIconTheme: const IconThemeData(
                color: Colors.white,
                size: 20,
              ),
              selectedItemDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sidebarActionColor.withOpacity(0.37),
                ),
                gradient: const LinearGradient(
                  colors: [sidebarAccentCanvasColor, sidebarCanvasColor],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 30,
                  )
                ],
              ),
              itemTextPadding: const EdgeInsets.only(left: 16),
              selectedItemTextPadding: const EdgeInsets.only(left: 16),
              itemPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sidebarCanvasColor),
              ),
              padding: const EdgeInsets.all(0),
            ),
            extendedTheme: const SidebarXTheme(
              width: 200,
              decoration: BoxDecoration(
                color: sidebarCanvasColor,
              ),
            ),
            headerDivider: sidebarDivider,
            footerDivider: sidebarDivider,
            headerBuilder: (context, extended) {
              return SizedBox(
                height: 100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: extended
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      buildCircularIcon(),
                      const SizedBox(width: 5,),
                      const Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(child: Text('Nombre Apellido', style: TextStyle(color: Colors.white, fontSize: 12),),),
                            SizedBox(width: 5,),
                            Flexible(child: Text('Rol', style: TextStyle(color: Colors.white, fontSize: 10),),),
                          ],
                        ),
                      ),
                    ],
                  ) : buildCircularIcon(),
                ),
              );
            },
            items: const [
              SidebarXItem(icon: Icons.bar_chart, label: 'Proyectos'),
              SidebarXItem(icon: Icons.groups, label: 'Practicantes'),
              SidebarXItem(icon: Icons.chat, label: 'Comunicados'),
            ],
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return pages[_controller.selectedIndex];
              },
            ),
          ),
        ],
      ),
    );
  }
}
