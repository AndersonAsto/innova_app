import 'package:flutter/material.dart';
import 'package:innova/environments/environments.dart';
import 'package:innova/login/authGate.dart';
import 'package:innova/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunicationsManagerScreen extends StatefulWidget {
  const CommunicationsManagerScreen({super.key});

  @override
  State<CommunicationsManagerScreen> createState() =>
      _CommunicationsManagerScreenState();
}

class _CommunicationsManagerScreenState extends State<CommunicationsManagerScreen> {
  List<Map<String, dynamic>> projects = [];
  bool isLoading = true;
  RealtimeChannel? announcementsChannel;
  Map<String, dynamic>? selectedAnnouncementProject;
  List<Map<String, dynamic>> announcements = [];
  RealtimeChannel? notificationsChannel;
  int unreadChatNotifications = 0;

  final TextEditingController announcementTitleController = TextEditingController();
  final TextEditingController announcementMessageController = TextEditingController();
  final TextEditingController announcementMeetingUrlController = TextEditingController();
  final TextEditingController announcementVideoUrlController = TextEditingController();
  final TextEditingController chatMessageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadProjects();
    loadAnnouncements();
    loadUnreadNotifications();
    subscribeAnnouncementsRealtime();
    subscribeNotificationsRealtime();
  }

  Future<void> markAnnouncementAsRead(int notificationId) async {
    await supabase
        .from('notificaciones')
        .update({
      'is_read': true,
    })
        .eq('id', notificationId);
  }

  @override
  void dispose() {
    announcementTitleController.dispose();
    announcementMessageController.dispose();
    announcementMeetingUrlController.dispose();
    announcementVideoUrlController.dispose();
    chatMessageController.dispose();
    if (announcementsChannel != null) {
      supabase.removeChannel(announcementsChannel!);
    }
    if (notificationsChannel != null) {
      supabase.removeChannel(notificationsChannel!);
    }
    super.dispose();
  }

  Future<void> loadUnreadNotifications() async {
    final managerId = SessionService.profile!['id'];

    final response = await supabase
        .from('notificaciones')
        .select()
        .eq('manager_id', managerId)
        .eq('is_read', false)
        .not('mensaje_id', 'is', null);

    if (!mounted) return;

    setState(() {
      unreadChatNotifications = response.length;
    });
  }

  void subscribeNotificationsRealtime() {
    final managerId = SessionService.profile!['id'];

    notificationsChannel = supabase
        .channel('manager_notifications_$managerId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notificaciones',
      callback: (_) async {
        await loadUnreadNotifications();
      },
    )
        .subscribe();
  }

  Future<void> markConversationAsRead(int conversationId) async {
    final managerId = SessionService.profile!['id'];

    final messages = await supabase
        .from('mensajes')
        .select('id')
        .eq('conversacion_id', conversationId)
        .eq('sender_type', 'Lider');

    final messageIds = List<Map<String, dynamic>>.from(messages)
        .map((e) => e['id'])
        .toList();

    if (messageIds.isEmpty) return;

    await supabase
        .from('notificaciones')
        .update({
      'is_read': true,
    })
        .eq('manager_id', managerId)
        .inFilter('mensaje_id', messageIds);

    await loadUnreadNotifications();
  }

  void subscribeAnnouncementsRealtime() {
    announcementsChannel = supabase
        .channel('manager_announcements_changes')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'anuncios_proyecto',
      callback: (_) async {
        await loadAnnouncements();
      },
    )
        .subscribe();
  }

  Widget buildAnnouncementCard(Map<String, dynamic> announcement) {
    final project = announcement['proyecto'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(
          left: BorderSide(
            color: appColors[0],
            width: 4,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showAnnouncementDetails(announcement),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: appColors[0].withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.campaign_rounded,
                    color: appColors[0],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: appColors[0],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: appColors[0].withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          project?['title'] ?? 'Proyecto no disponible',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: appColors[0],
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        announcement['message_text'] ?? '',
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

  void showAnnouncementDetails(Map<String, dynamic> announcement) {
    final project = announcement['proyecto'];

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
                    'Detalle del anuncio',
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
                  announcement['title'],
                ),

                infoTile(
                  'Mensaje',
                  announcement['message_text'],
                ),

                if (announcement['meeting_url'] != null &&
                    announcement['meeting_url'].toString().isNotEmpty)
                  infoTile(
                    'Enlace de reunión',
                    announcement['meeting_url'],
                  ),

                if (announcement['video_url'] != null &&
                    announcement['video_url'].toString().isNotEmpty)
                  infoTile(
                    'Video',
                    announcement['video_url'],
                  ),

                infoTile(
                  'Fecha',
                  announcement['created_at'],
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

  Widget buildAnnouncementsTab() {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        if (announcements.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Text('Aún no hay anuncios registrados'),
            ),
          )
        else
          ...announcements.map(buildAnnouncementCard),
      ],
    );
  }

  Future<void> loadAnnouncements() async {
    final response = await supabase
        .from('anuncios_proyecto')
        .select('''
        *,
        proyecto(
          id,
          title
        )
      ''')
        .eq('status', true)
        .order('created_at', ascending: false);

    if (!mounted) return;

    setState(() {
      announcements = List<Map<String, dynamic>>.from(response);
    });
  }



  Future<void> loadProjects() async {
    try {
      final response = await supabase
          .from('proyecto')
          .select()
          .eq('status', true)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        projects = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<List<Map<String, dynamic>>> getProjectParticipants(
      int projectId,
      ) async {
    final response = await supabase
        .from('proyecto_participantes')
        .select()
        .eq('proyecto_id', projectId)
        .eq('status', true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getProjectLeader(
      int projectId,
      ) async {
    final response = await supabase
        .from('proyecto_participantes')
        .select('''
          *,
          practicantes(
            id,
            names,
            fathers_surname,
            mothers_surname,
            institutional_email
          )
        ''')
        .eq('proyecto_id', projectId)
        .eq('role', 'Líder')
        .eq('status', true)
        .maybeSingle();

    return response;
  }

  Future<void> createAnnouncement() async {
    final project = selectedAnnouncementProject;
    final title = announcementTitleController.text.trim();
    final message = announcementMessageController.text.trim();
    final meetingUrl = announcementMeetingUrlController.text.trim();
    final videoUrl = announcementVideoUrlController.text.trim();

    if (project == null) {
      throw Exception('Seleccione un proyecto');
    }

    if (title.isEmpty) {
      throw Exception('Ingrese un título');
    }

    if (message.isEmpty) {
      throw Exception('Ingrese el mensaje del anuncio');
    }

    final managerId = SessionService.profile!['id'];
    final projectId = project['id'];

    final announcement = await supabase
        .from('anuncios_proyecto')
        .insert({
      'proyecto_id': projectId,
      'created_by_type': 'Gestor',
      'created_by_manager_id': managerId,
      'title': title,
      'message_text': message,
      'meeting_url': meetingUrl.isEmpty ? null : meetingUrl,
      'video_url': videoUrl.isEmpty ? null : videoUrl,
      'status': true,
    })
        .select()
        .single();

    final participants = await getProjectParticipants(projectId);

    if (participants.isNotEmpty) {
      await supabase.from('notificaciones').insert(
        participants.map((participant) {
          return {
            'practicante_id': participant['practicante_id'],
            'anuncio_id': announcement['id'],
            'mensaje_id': null,
            'is_read': false,
          };
        }).toList(),
      );
    }

    announcementTitleController.clear();
    announcementMessageController.clear();
    announcementMeetingUrlController.clear();
    announcementVideoUrlController.clear();

    if (!mounted) return;

    setState(() {
      selectedAnnouncementProject = null;
    });
  }

  Future<Map<String, dynamic>> getOrCreateConversation({
    required int projectId,
    required int leaderId,
  }) async {
    final managerId = SessionService.profile!['id'];

    final existing = await supabase
        .from('conversaciones')
        .select()
        .eq('proyecto_id', projectId)
        .eq('manager_id', managerId)
        .eq('lider_id', leaderId)
        .maybeSingle();

    if (existing != null) {
      return existing;
    }

    final created = await supabase
        .from('conversaciones')
        .insert({
      'proyecto_id': projectId,
      'manager_id': managerId,
      'lider_id': leaderId,
      'status': true,
    })
        .select()
        .single();

    return created;
  }

  Future<List<Map<String, dynamic>>> loadMessages(
      int conversationId,
      ) async {
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
    required int leaderId,
  }) async {
    final text = chatMessageController.text.trim();

    if (text.isEmpty) return;

    final managerId = SessionService.profile!['id'];

    final message = await supabase
        .from('mensajes')
        .insert({
      'conversacion_id': conversationId,
      'sender_type': 'Gestor',
      'sender_manager_id': managerId,
      'sender_practicante_id': null,
      'message_text': text,
      'meeting_url': null,
      'video_url': null,
      'status': true,
    })
        .select()
        .single();

    await supabase.from('notificaciones').insert({
      'practicante_id': leaderId,
      'mensaje_id': message['id'],
      'anuncio_id': null,
      'is_read': false,
    });

    chatMessageController.clear();
  }

  Future<void> openChatForProject(
      Map<String, dynamic> project,
      ) async {
    final leaderParticipant = await getProjectLeader(project['id']);

    if (leaderParticipant == null) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text(
              'Sin líder asignado',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Este proyecto aún no tiene líder. Asigne un líder desde la gestión de participantes del proyecto.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );

      return;
    }

    final leader = leaderParticipant['practicantes'];
    final conversation = await getOrCreateConversation(
      projectId: project['id'],
      leaderId: leader['id'],
    );

    if (!mounted) return;

    await showChatModal(
      project: project,
      leader: leader,
      conversation: conversation,
    );
  }

  Future<void> showChatModal({
    required Map<String, dynamic> project,
    required Map<String, dynamic> leader,
    required Map<String, dynamic> conversation,
  }) async {
    await markConversationAsRead(conversation['id']);
    List<Map<String, dynamic>> messages = [];
    bool loadingMessages = true;
    RealtimeChannel? chatChannel;

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
                  .channel('chat_${conversation['id']}')
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
                            project['title'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Líder: ${leader['names']} ${leader['fathers_surname']}',
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
                          ? const Center(child: Text('Aún no hay mensajes'))
                          : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (_, index) {
                          final message = messages[index];
                          final isMe = message['sender_type'] == 'Gestor';
                          final createdAt =
                          DateTime.parse(message['created_at']).toLocal();

                          final formattedDate =
                              "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";

                          return Align(
                            alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              constraints: const BoxConstraints(maxWidth: 320),
                              decoration: BoxDecoration(
                                color: isMe ? appColors[0] : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message['message_text'] ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      color:
                                      isMe ? Colors.white70 : Colors.black54,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    SafeArea(
                      top: false,
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
                                  leaderId: leader['id'],
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

  Future<void> sendAnnouncements() async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: buildAnnouncementsTabContent(),
          ),
        );
      },
    );
  }

  Widget buildAnnouncementsTabContent() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F6FA),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    appColors[0],
                    appColors[0].withValues(alpha: 0.78),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: appColors[0].withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enviar anuncio',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'El comunicado será visible para los integrantes del proyecto.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _announcementDropdown(),

            const SizedBox(height: 12),

            _announcementField(
              controller: announcementTitleController,
              label: 'Título',
              icon: Icons.title_rounded,
            ),

            const SizedBox(height: 12),

            _announcementField(
              controller: announcementMessageController,
              label: 'Mensaje',
              icon: Icons.notes_rounded,
              maxLines: 5,
            ),

            const SizedBox(height: 12),

            _announcementField(
              controller: announcementMeetingUrlController,
              label: 'Enlace de reunión',
              icon: Icons.videocam_outlined,
              optional: true,
            ),

            const SizedBox(height: 12),

            _announcementField(
              controller: announcementVideoUrlController,
              label: 'Video',
              icon: Icons.play_circle_outline_rounded,
              optional: true,
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors[0],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  try {
                    await createAnnouncement();
                    await loadAnnouncements();

                    if (!mounted) return;

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Anuncio enviado correctamente'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                      ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Enviar anuncio',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _announcementDropdown() {
    return DropdownButtonFormField<Map<String, dynamic>>(
      isExpanded: true,
      value: selectedAnnouncementProject,
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: 'Proyecto',
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
        prefixIcon: Icon(
          Icons.folder_outlined,
          color: appColors[0],
          size: 19,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: appColors[0],
            width: 1.3,
          ),
        ),
      ),
      items: projects.map((project) {
        return DropdownMenuItem<Map<String, dynamic>>(
          value: project,
          child: Text(
            project['title'],
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedAnnouncementProject = value;
        });
      },
    );
  }

  Widget _announcementField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool optional = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF1F2937),
      ),
      decoration: InputDecoration(
        labelText: optional ? '$label (opcional)' : label,
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
        prefixIcon: Icon(
          icon,
          color: appColors[0],
          size: 19,
        ),
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: appColors[0],
            width: 1.3,
          ),
        ),
      ),
    );
  }

  Widget emptyState({
    required IconData icon,
    required String text,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildChatsTab() {
    if (projects.isEmpty) {
      return emptyState(
        icon: Icons.chat_bubble_outline_rounded,
        text: 'No hay proyectos disponibles para iniciar chats.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: projects.length,
      itemBuilder: (_, index) {
        final project = projects[index];
        final title = project['title'] ?? 'Proyecto';
        final initials = title.toString().isNotEmpty
            ? title.toString().substring(0, 1).toUpperCase()
            : 'P';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
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
                await openChatForProject(project);
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            appColors[0],
                            appColors[0].withValues(alpha: 0.75),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
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
                            'Chat con líder del proyecto',
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
                      Icons.chat_bubble_outline_rounded,
                      color: appColors[0],
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    final isMobile = MediaQuery.of(context).size.width < 700;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: appColors[0],
          automaticallyImplyLeading: false,
          title: screenWidth > 700 ? const Text('Comunicados', style: TextStyle(color: Colors.white, fontSize: 15),) : null,
          toolbarHeight: isMobile ? 10 : kToolbarHeight,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              const Tab(
                icon: Icon(Icons.campaign),
                text: 'Anuncios',
              ),
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
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            buildAnnouncementsTab(),
            buildChatsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => sendAnnouncements(),
          mini: true,
          backgroundColor: appColors[0],
          tooltip: 'Crear anuncio',
          hoverColor: const Color(0x52FFFFFF),
          child: const Icon(Icons.add, color: Colors.white,),
        ),
      ),
    );
  }
}