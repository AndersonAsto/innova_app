import 'package:flutter/material.dart';
import 'package:innova/environments/environments.dart';
import 'package:innova/login/authGate.dart';
import 'package:innova/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunicationsInternScreen extends StatefulWidget {
  const CommunicationsInternScreen({super.key});

  @override
  State<CommunicationsInternScreen> createState() => _CommunicationsInternScreenState();
}

class _CommunicationsInternScreenState extends State<CommunicationsInternScreen> {
  List<Map<String, dynamic>> announcements = [];
  List<Map<String, dynamic>> leaderConversations = [];
  int unreadChatNotifications = 0;
  bool isLoading = true;
  bool isLeaderUser = false;

  final TextEditingController chatMessageController = TextEditingController();
  RealtimeChannel? announcementsChannel;
  @override
  void initState() {
    super.initState();
    loadData();
    loadUnreadChatNotifications();
    subscribeAnnouncementsRealtime();
  }

  @override
  void dispose() {
    if (announcementsChannel != null) {
      supabase.removeChannel(announcementsChannel!);
    }
    chatMessageController.dispose();
    super.dispose();
  }

  Future<void> loadUnreadChatNotifications() async {
    final myId = SessionService.profile!['id'];

    final response = await supabase
        .from('notificaciones')
        .select()
        .eq('practicante_id', myId)
        .eq('is_read', false)
        .not('mensaje_id', 'is', null);

    if (!mounted) return;

    setState(() {
      unreadChatNotifications = response.length;
    });
  }

  Future<void> markConversationAsRead(int conversationId) async {
    final myId = SessionService.profile!['id'];

    final messages = await supabase
        .from('mensajes')
        .select('id')
        .eq('conversacion_id', conversationId)
        .eq('sender_type', 'Gestor');

    final messageIds = List<Map<String, dynamic>>.from(messages)
        .map((e) => e['id'])
        .toList();

    if (messageIds.isEmpty) return;

    await supabase
        .from('notificaciones')
        .update({
      'is_read': true,
    })
        .eq('practicante_id', myId)
        .inFilter('mensaje_id', messageIds);

    await loadUnreadChatNotifications();
  }

  void subscribeAnnouncementsRealtime() {
    announcementsChannel = supabase
        .channel('intern_announcements_${SessionService.profile!['id']}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notificaciones',
      callback: (_) async {
        await loadData();
        await loadUnreadChatNotifications();
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'anuncios_proyecto',
      callback: (_) async {
        await loadData();
        await loadUnreadChatNotifications();
      },
    )
        .subscribe();
  }

  Future<void> loadData() async {
    final myId = SessionService.profile!['id'];

    final leaderProjects = await supabase
        .from('proyecto_participantes')
        .select('''
          *,
          proyecto(
            id,
            title
          )
        ''')
        .eq('practicante_id', myId)
        .eq('role', 'Líder')
        .eq('status', true);

    final notificationsResponse = await supabase
        .from('notificaciones')
        .select('''
          *,
          anuncios_proyecto(
            *,
            proyecto(
              id,
              title
            )
          )
        ''')
        .eq('practicante_id', myId)
        .not('anuncio_id', 'is', null)
        .order('created_at', ascending: false);

    final conversationsResponse = await supabase
        .from('conversaciones')
        .select('''
          *,
          proyecto(
            id,
            title
          ),
          administradores_gestores(
            id,
            names,
            fathers_surname,
            role
          )
        ''')
        .eq('lider_id', myId)
        .eq('status', true)
        .order('updated_at', ascending: false);

    if (!mounted) return;

    setState(() {
      isLeaderUser = List<Map<String, dynamic>>.from(leaderProjects).isNotEmpty;
      announcements = List<Map<String, dynamic>>.from(notificationsResponse);
      leaderConversations =
      List<Map<String, dynamic>>.from(conversationsResponse);
      isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> loadMessages(int conversationId) async {
    final response = await supabase
        .from('mensajes')
        .select()
        .eq('conversacion_id', conversationId)
        .eq('status', true)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> sendMessage({
    required int conversationId,
    required int managerId,
  }) async {
    final text = chatMessageController.text.trim();

    if (text.isEmpty) return;

    final myId = SessionService.profile!['id'];

    final message = await supabase
        .from('mensajes')
        .insert({
      'conversacion_id': conversationId,
      'sender_type': 'Lider',
      'sender_manager_id': null,
      'sender_practicante_id': myId,
      'message_text': text,
      'meeting_url': null,
      'video_url': null,
      'status': true,
    })
        .select()
        .single();

    await supabase.from('notificaciones').insert({
      'manager_id': managerId,
      'practicante_id': null,
      'mensaje_id': message['id'],
      'anuncio_id': null,
      'is_read': false,
    });

    chatMessageController.clear();
  }

  void showAnnouncementDetails(Map<String, dynamic> notification) {
    final announcement = notification['anuncios_proyecto'];
    final project = announcement?['proyecto'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [appColors[0], appColors[0].withOpacity(0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: appColors[0].withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Detalle del comunicado',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                infoTile(
                  Icons.folder_outlined,
                  'Proyecto',
                  project?['title'] ?? 'Proyecto no disponible',
                ),
                infoTile(
                  Icons.title_rounded,
                  'Título',
                  announcement?['title'],
                ),
                infoTile(
                  Icons.notes_rounded,
                  'Mensaje',
                  announcement?['message_text'],
                ),
                if (announcement?['meeting_url'] != null && announcement!['meeting_url'].toString().isNotEmpty)
                  infoTile(
                    Icons.videocam_outlined,
                    'Enlace de reunión',
                    announcement?['meeting_url'],
                  ),
                if (announcement?['video_url'] != null && announcement!['video_url'].toString().isNotEmpty)
                  infoTile(
                    Icons.play_circle_outline,
                    'Video',
                    announcement?['video_url'],
                  ),
                infoTile(
                  Icons.schedule_rounded,
                  'Fecha',
                  announcement?['created_at'],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColors[0],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text(
                      'Cerrar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showChatModal(Map<String, dynamic> conversation) async {
    await markConversationAsRead(conversation['id']);
    List<Map<String, dynamic>> messages = [];
    bool loadingMessages = true;

    RealtimeChannel? chatChannel;

    final project = conversation['proyecto'];
    final manager = conversation['administradores_gestores'];

    Future<void> refreshMessages(
        void Function(void Function()) setModalState,
        ) async {
      final response = await loadMessages(conversation['id']);

      setModalState(() {
        messages = response;
        loadingMessages = false;
      });
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (loadingMessages && chatChannel == null) {
              chatChannel = supabase
                  .channel('intern_chat_${conversation['id']}')
                  .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'mensajes',
                callback: (_) async {
                  await refreshMessages(setModalState);
                },
              )
                  .subscribe();

              refreshMessages(setModalState);
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [appColors[0], appColors[0].withOpacity(0.75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project?['title'] ?? 'Proyecto',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Gestor: ${manager?['names'] ?? ''} ${manager?['fathers_surname'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF5F6FA),
                        child: loadingMessages
                            ? const Center(child: CircularProgressIndicator())
                            : messages.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.forum_outlined,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Aún no hay mensajes',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                            : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: messages.length,
                          itemBuilder: (_, index) {
                            final message = messages[index];
                            final isMe =
                                message['sender_type'] == 'Lider';
                            final createdAt = DateTime.parse(message['created_at']).toLocal();
                            final formattedDate = "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";
                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? appColors[0]
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(14),
                                    topRight: const Radius.circular(14),
                                    bottomLeft: Radius.circular(isMe ? 14 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 14),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(message['message_text'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 13.5,),),
                                    const SizedBox(height: 4),
                                    Text(formattedDate, style: TextStyle(color: isMe ? Colors.white70 : Colors.black45, fontSize: 8,),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: chatMessageController,
                                decoration: InputDecoration(
                                  hintText: 'Escribir mensaje...',
                                  filled: true,
                                  fillColor: const Color(0xFFF5F6FA),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: appColors[0],
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: () async {
                                  await sendMessage(
                                    conversationId: conversation['id'],
                                    managerId: conversation['manager_id'],
                                  );

                                  await refreshMessages(setModalState);
                                },
                                icon: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (chatChannel != null) {
      supabase.removeChannel(chatChannel!);
    }

    chatMessageController.clear();
  }

  Widget buildAnnouncementCard(Map<String, dynamic> notification) {
    final announcement = notification['anuncios_proyecto'];
    final project = announcement?['proyecto'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showAnnouncementDetails(notification);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [appColors[0], appColors[0].withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement?['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: appColors[0],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: appColors[0].withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          project?['title'] ?? 'Proyecto no disponible',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                            color: appColors[0],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        announcement?['message_text'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildChatCard(Map<String, dynamic> conversation) {
    final project = conversation['proyecto'];
    final manager = conversation['administradores_gestores'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await showChatModal(conversation);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [appColors[0], appColors[0].withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project?['title'] ?? 'Proyecto',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: appColors[0],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gestor: ${manager?['names'] ?? ''} ${manager?['fathers_surname'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildAnnouncementsTab() {
    if (announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No tienes comunicados por ahora',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(15),
      children: announcements.map(buildAnnouncementCard).toList(),
    );
  }

  Widget buildChatsTab() {
    if (!isLeaderUser) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No eres líder de ningún proyecto. Sólo puedes visualizar comunicados.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    if (leaderConversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'Aún no tienes conversaciones activas con gestores.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(15),
      children: leaderConversations.map(buildChatCard).toList(),
    );
  }

  Widget infoTile(IconData icon, String title, dynamic value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = isLeaderUser
        ? [
      const Tab(icon: Icon(Icons.campaign), text: 'Anuncios'),
      Tab(
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.chat),
            if (unreadChatNotifications > 0)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadChatNotifications.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        text: 'Chats',
      ),
    ]
        : const [
      Tab(icon: Icon(Icons.campaign), text: 'Anuncios'),
    ];

    final views = isLeaderUser
        ? [
      buildAnnouncementsTab(),
      buildChatsTab(),
    ]
        : [
      buildAnnouncementsTab(),
    ];

    double screenWidth = MediaQuery.of(context).size.width;

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: appColors[0],
          automaticallyImplyLeading: false,
          elevation: 0,
          title: const Text(
            'Comunicados',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: tabs,
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: views,
        ),
      ),
    );
  }
}