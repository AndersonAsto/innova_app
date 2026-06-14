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

  bool isLoading = true;
  bool isLeaderUser = false;

  final TextEditingController chatMessageController = TextEditingController();
  RealtimeChannel? announcementsChannel;
  @override
  void initState() {
    super.initState();
    loadData();
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

  void subscribeAnnouncementsRealtime() {
    announcementsChannel = supabase
        .channel('intern_announcements_${SessionService.profile!['id']}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notificaciones',
      callback: (_) async {
        await loadData();
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'anuncios_proyecto',
      callback: (_) async {
        await loadData();
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
      'practicante_id': myId,
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
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: appColors[0],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Detalle del comunicado',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                infoTile(
                  'Proyecto',
                  project?['title'] ?? 'Proyecto no disponible',
                ),
                infoTile(
                  'Título',
                  announcement?['title'],
                ),
                infoTile(
                  'Mensaje',
                  announcement?['message_text'],
                ),
                if (announcement?['meeting_url'] != null && announcement!['meeting_url'].toString().isNotEmpty)
                  infoTile(
                    'Enlace de reunión',
                    announcement?['meeting_url'],
                  ),
                if (announcement?['video_url'] != null && announcement!['video_url'].toString().isNotEmpty)
                  infoTile(
                    'Video',
                    announcement?['video_url'],
                  ),
                infoTile(
                  'Fecha',
                  announcement?['created_at'],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Cerrar'),
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
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: appColors[0],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project?['title'] ?? 'Proyecto',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Gestor: ${manager?['names'] ?? ''} ${manager?['fathers_surname'] ?? ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: loadingMessages
                          ? const Center(child: CircularProgressIndicator())
                          : messages.isEmpty
                          ? const Center(
                        child: Text('Aún no hay mensajes'),
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
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              constraints: const BoxConstraints(
                                maxWidth: 320,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? appColors[0]
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(message['message_text'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black),),
                                  const SizedBox(height: 4),
                                  Text(formattedDate, style: TextStyle(color: isMe ? Colors.white70 : Colors.black54, fontSize: 8,),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: chatMessageController,
                                decoration: const InputDecoration(
                                  hintText: 'Escribir mensaje...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () async {
                                await sendMessage(
                                  conversationId: conversation['id'],
                                  managerId: conversation['manager_id'],
                                );

                                await refreshMessages(setModalState);
                              },
                              icon: Icon(
                                Icons.send,
                                color: appColors[0],
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

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: appColors[0],
          child: const Icon(
            Icons.campaign,
            color: Colors.white,
            size: 18,
          ),
        ),
        title: Text(
          announcement?['title'] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: appColors[0],
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project?['title'] ?? 'Proyecto no disponible',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            Text(
              announcement?['message_text'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 15,
          color: Colors.black,
        ),
        onTap: () {
          showAnnouncementDetails(notification);
        },
      ),
    );
  }

  Widget buildChatCard(Map<String, dynamic> conversation) {
    final project = conversation['proyecto'];
    final manager = conversation['administradores_gestores'];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: appColors[0],
          child: const Icon(
            Icons.chat,
            color: Colors.white,
            size: 18,
          ),
        ),
        title: Text(
          project?['title'] ?? 'Proyecto',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: appColors[0],
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Gestor: ${manager?['names'] ?? ''} ${manager?['fathers_surname'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 15,
          color: Colors.black,
        ),
        onTap: () async {
          await showChatModal(conversation);
        },
      ),
    );
  }

  Widget buildAnnouncementsTab() {
    if (announcements.isEmpty) {
      return const Center(
        child: Text('No tienes comunicados por ahora'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(15),
      children: announcements.map(buildAnnouncementCard).toList(),
    );
  }

  Widget buildChatsTab() {
    if (!isLeaderUser) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(25),
          child: Text(
            'No eres líder de ningún proyecto. Sólo puedes visualizar comunicados.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (leaderConversations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(25),
          child: Text(
            'Aún no tienes conversaciones activas con gestores.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(15),
      children: leaderConversations.map(buildChatCard).toList(),
    );
  }

  Widget infoTile(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value?.toString() ?? '',
            style: const TextStyle(
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = isLeaderUser
        ? const [
      Tab(icon: Icon(Icons.campaign), text: 'Anuncios'),
      Tab(icon: Icon(Icons.chat), text: 'Chats'),
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

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: appColors[0],
          automaticallyImplyLeading: false,
          title: const Text(
            'Comunicados',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
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