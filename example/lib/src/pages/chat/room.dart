import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:perdiem_app/flutter_supabase_chat_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/l10n/generated/app_localizations.dart';

import '../../services/budget_proposal_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/service_completion_message.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({
    super.key,
    required this.room,
  });

  final types.Room room;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  bool _isAttachmentUploading = false;
  late SupabaseChatController _chatController;
  types.User? _localUser;
  String _realUserRole = 'user';

  @override
  void initState() {
    _chatController = SupabaseChatController(room: widget.room);
    super.initState();
    _loadLocalCurrentUser();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalCurrentUser() async {
    final sbUser = SupabaseChatCore.instance.loggedSupabaseUser;
    if (sbUser == null) return;

    try {
      // Usamos la configuración del core para saber de qué tabla sacar los datos
      final tableName = SupabaseChatCore.instance.config.usersTableName;
      final schema = SupabaseChatCore.instance.config.schema;
      
      final data = await Supabase.instance.client
          .schema(schema)
          .from(tableName)
          .select()
          .eq('id', sbUser.id)
          .single();
 
      // Convertimos el mapa a mutable y cambiamos 'worker' por 'user' solo localmente
      final Map<String, dynamic> safeData = Map<String, dynamic>.from(data);
      
      final dbRole = safeData['role'] as String?;
      _realUserRole = dbRole ?? 'user';

      if (safeData['role'] == 'worker') {
        safeData['role'] = 'user'; // Engañamos solo a la UI del chat
      }

      if (mounted) {
        setState(() {
          _localUser = types.User.fromJson(safeData);
        });
      }
    } catch (e) {
      debugPrint('Error recuperando usuario local: $e');
    }
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) { 
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
        child: SizedBox(
          height: 130,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleImageSelection();
                  },
                  child: Row(
                    children: [
                      Icon(Icons.image),
                      Text(l10n.image),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleFileSelection();
                  },
                  child: Row(
                    children: [
                      Icon(Icons.attach_file),
                      Text(l10n.file),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      _setAttachmentUploading(true);
      try {
        final bytes = result.files.single.bytes;
        final name = result.files.single.name;
        final uploadResult = await SupabaseChatCore.instance
            .uploadAsset(widget.room, name, bytes!);
        final message = types.PartialFile(
          mimeType: uploadResult.mimeType,
          name: name,
          size: result.files.single.size,
          uri: uploadResult.url,
        );
        await SupabaseChatCore.instance.sendMessage(message, widget.room.id);
        _setAttachmentUploading(false);
      } finally {
        _setAttachmentUploading(false);
      }
    }
  }

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );
    if (result != null) {
      _setAttachmentUploading(true);
      final bytes = await result.readAsBytes();
      final size = bytes.length;
      final image = await decodeImageFromList(bytes);
      final name = result.name;
      try {
        final uploadResult = await SupabaseChatCore.instance
            .uploadAsset(widget.room, name, bytes);
        final message = types.PartialImage(
          height: image.height.toDouble(),
          name: name,
          size: size,
          uri: uploadResult.url,
          width: image.width.toDouble(),
        );
        await SupabaseChatCore.instance.sendMessage(
          message,
          widget.room.id,
        );
        _setAttachmentUploading(false);
      } finally {
        _setAttachmentUploading(false);
      }
    }
  }

  void _handleMessageTap(BuildContext _, types.Message message) async {
    if (message is types.FileMessage) {
      final client = http.Client();
      final request = await client.get(
        Uri.parse(message.uri),
        headers: SupabaseChatCore.instance.httpSupabaseHeaders,
      );
      final result = await FileSaver.instance.saveFile(
        name: message.uri.split('/').last,
        bytes: request.bodyBytes,
      );
      await OpenFilex.open(result);
    }
  }

  // Esta función crea un mensaje personalizado para preguntar sobre la finalización del servicio
  Future<void> _createServiceCompletionMessage(String proposalId) async {
    try {
      // Obtener la propuesta
      final proposal = await BudgetProposalService.getProposalById(proposalId);

      if (proposal == null || proposal.status != 'accepted') {
        return;
      }

      // Crear mensaje personalizado
      final message = types.PartialCustom(
        metadata: {
          'type': 'service_completion',
          'proposal_id': proposalId,
        },
      );

      await SupabaseChatCore.instance.sendMessage(
        message,
        widget.room.id,
      );
    } catch (e) {
      debugPrint('Error al crear mensaje de confirmación de servicio: $e');
    }
  }

// Modificar el método _handleAcceptProposal en RoomPage para que después de aceptar una propuesta, cree el mensaje de confirmación de servicio
  Future<void> _handleAcceptProposal(BudgetProposal proposal) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await BudgetProposalService.acceptProposal(proposal.id);

      // Enviar mensaje al chat informando sobre la aceptación
      final message = types.PartialText(
        text: '${l10n.budgetAccept} \$${proposal.amount.toStringAsFixed(0)}',
      );

      await SupabaseChatCore.instance.sendMessage(
        message,
        widget.room.id,
      );
      
      // Notificar al remitente original
      await NotificationService.sendNewMessageNotification(
        proposal.senderId,
        SupabaseChatCore.instance.loggedUser?.firstName ?? 'Usuario',
        l10n.yourBudgetAccept,
        widget.room.id,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.uHvAccept),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error al aceptar propuesta: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.errorAccepting} ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) async {
    final updatedMessage = message.copyWith(previewData: previewData);

    await SupabaseChatCore.instance
        .updateMessage(updatedMessage, widget.room.id);
  }

  Future<void> _handleSendPressed(types.PartialText message) async {
    await _chatController.endTyping();
    await SupabaseChatCore.instance.sendMessage(
      message,
      widget.room.id,
    );
    // Añadir notificación para los mensajes nuevos
    // Solo enviar notificación al otro usuario en la sala (no al autor)
    final currentUserId = SupabaseChatCore.instance.loggedSupabaseUser?.id;
    if (currentUserId != null && widget.room.users.length > 1) {
      // Encontrar al otro usuario (no el remitente)
      final otherUser = widget.room.users.firstWhere(
            (user) => user.id != currentUserId,
        orElse: () => types.User(id: ''), // Usuario vacío si no hay otro usuario
      );

      if (otherUser.id.isNotEmpty) {
        try {
          debugPrint('📨 Enviando notificación de nuevo mensaje al usuario: ${otherUser.id}');

          // Obtener nombre del remitente (usuario actual)
          final senderName = SupabaseChatCore.instance.loggedUser?.firstName ?? 'Usuario';

          await NotificationService.sendNewMessageNotification(
            otherUser.id,
            senderName,
            message.text,
            widget.room.id,
          );

          debugPrint('Notificación de mensaje enviada correctamente');
        } catch (e) {
          debugPrint('⚠️ Error al enviar notificación de mensaje: $e');
          debugPrint('Stack trace: ${StackTrace.current}');
          // Continuamos aunque falle la notificación
        }
      }
    }
  }

  void _setAttachmentUploading(bool uploading) {
    setState(() {
      _isAttachmentUploading = uploading;
    });
  }

  Future<void> _sendBudgetProposal(double amount, String description, String providerId) async {
    final l10n = AppLocalizations.of(context)!;
    final currentUserId = SupabaseChatCore.instance.loggedSupabaseUser?.id;
    if (currentUserId == null) return;

    try {
      final otherUser = widget.room.users.firstWhere(
            (user) => user.id != currentUserId,
        orElse: () => types.User(id: ''),
      );

      if (otherUser.id.isEmpty) return;

      final proposal = await BudgetProposalService.createProposal(
        roomId: widget.room.id,
        receiverId: otherUser.id,
        amount: amount,
        description: description,
        providerId: providerId, // Pasamos el proveedor a la BD
      );

      final message = types.PartialCustom(
        metadata: {
          'type': 'budget_proposal',
          'proposal_id': proposal.id,
        },
      );

      await SupabaseChatCore.instance.sendMessage(message, widget.room.id);

      await NotificationService.sendNewMessageNotification(
        otherUser.id,
        SupabaseChatCore.instance.loggedUser?.firstName ?? 'Usuario',
        '${l10n.newBudgetProp} \$${amount.toStringAsFixed(0)}',
        widget.room.id,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.propSended), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint('Error al enviar propuesta de presupuesto: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorSendProp} ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  // Función para construir el indicador de propuesta activa
  Widget _buildActiveProposalIndicator(List<BudgetProposal> proposals) {
    final l10n = AppLocalizations.of(context)!;
    // Encontrar propuesta pendiente más reciente
    final pendingProposal = proposals.where((p) => p.status == 'pending').toList();
    if (pendingProposal.isEmpty) return const SizedBox.shrink();

    final latestProposal = pendingProposal.reduce(
            (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );

    // Solo mostrar para el destinatario
    if (latestProposal.receiverId != SupabaseChatCore.instance.loggedSupabaseUser?.id) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 4,
        color: Colors.amber[100],
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Icon(Icons.notifications, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.pendingProp,
                  style: TextStyle(color: Colors.amber[800]),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Hacer scroll hasta el mensaje de la propuesta
                },
                child: Text(l10n.view),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Manejar el rechazo de una propuesta
  Future<void> _handleRejectProposal(BudgetProposal proposal) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await BudgetProposalService.rejectProposal(proposal.id);

      // Enviar mensaje al chat informando sobre el rechazo
      final message = types.PartialText(
        text: '${l10n.budgetRejected} \$${proposal.amount.toStringAsFixed(0)}',
      );

      await SupabaseChatCore.instance.sendMessage(
        message,
        widget.room.id,
      );

      // Notificar al remitente original
      await NotificationService.sendNewMessageNotification(
        proposal.senderId,
        SupabaseChatCore.instance.loggedUser?.firstName ?? 'Usuario',
        l10n.yourBudgetRejected,
        widget.room.id,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.uHvReject),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('Error al rechazar propuesta: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.errorRejectBudget} ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Mostrar diálogo para crear una contrapropuesta
  void _handleCounterProposal(BudgetProposal originalProposal) {
    final l10n = AppLocalizations.of(context)!;
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    // Pre-llenar con la propuesta original
    amountController.text = originalProposal.amount.toStringAsFixed(0);
    descriptionController.text = originalProposal.description;

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.countProp),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: l10n.amount,
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: l10n.description,
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (amountController.text.isNotEmpty) {
                _sendCounterProposal(
                  originalProposal,
                  double.parse(amountController.text),
                  descriptionController.text,
                );
                Navigator.pop(context);
              }
            },
            child: Text(l10n.sendCountProp),
          ),
        ],
      ),
    );
  }

  // Enviar una contrapropuesta
  Future<void> _sendCounterProposal(
      BudgetProposal originalProposal,
      double amount,
      String description,
      ) async {
    final l10n = AppLocalizations.of(context)!;
    final currentUserId = SupabaseChatCore.instance.loggedSupabaseUser?.id;
    if (currentUserId == null) return;

    try {
      final counterProposal = await BudgetProposalService.createCounterProposal(
        originalProposal: originalProposal, // Pasamos el objeto completo
        roomId: widget.room.id,
        receiverId: originalProposal.senderId,
        amount: amount,
        description: description,
      );

      final message = types.PartialCustom(
        metadata: {
          'type': 'budget_proposal',
          'proposal_id': counterProposal.id,
          'is_counter': true,
        },
      );

      await SupabaseChatCore.instance.sendMessage(message, widget.room.id);

      await NotificationService.sendNewMessageNotification(
        originalProposal.senderId,
        SupabaseChatCore.instance.loggedUser?.firstName ?? 'Usuario',
        '${l10n.newCountProp} \$${amount.toStringAsFixed(0)}',
        widget.room.id,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sendedCountProp), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint('Error al enviar contrapropuesta: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorSendingCountProp} ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  void _showBudgetDialog() {
    final l10n = AppLocalizations.of(context)!;
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    bool iAmProvidingService = true; // Estado por defecto

    showDialog(
      context: context,
      builder: (BuildContext context) => StatefulBuilder( // Usamos StatefulBuilder para actualizar el switch
          builder: (context, setStateDialog) => AlertDialog(
              title: Text(l10n.createBudget),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selector de Rol
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('¿Cuál es tu rol en este trabajo?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        RadioListTile<bool>(
                          title: const Text('Yo prestaré el servicio (Cobro)', style: TextStyle(fontSize: 13)),
                          value: true,
                          groupValue: iAmProvidingService,
                          dense: true,
                          onChanged: (value) => setStateDialog(() => iAmProvidingService = value!),
                        ),
                        RadioListTile<bool>(
                          title: const Text('Yo contrato el servicio (Pago)', style: TextStyle(fontSize: 13)),
                          value: false,
                          groupValue: iAmProvidingService,
                          dense: true,
                          onChanged: (value) => setStateDialog(() => iAmProvidingService = value!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: l10n.amount,
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: l10n.description,
                      prefixIcon: const Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (amountController.text.isNotEmpty) {
                      final currentUserId = SupabaseChatCore.instance.loggedSupabaseUser?.id;
                      final otherUser = widget.room.users.firstWhere((u) => u.id != currentUserId);

                      // Definimos quién es el proveedor basado en lo que seleccionó
                      final providerId = iAmProvidingService ? currentUserId! : otherUser.id;

                      _sendBudgetProposal(
                        double.parse(amountController.text),
                        descriptionController.text,
                        providerId, // Se lo pasamos a la función
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: Text(l10n.send),
                ),
              ],
            )
      ),
    );
  }

  @override
  Widget build(BuildContext context) { 
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
    appBar: AppBar(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Text(l10n.conversation),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'budget') {
              _showBudgetDialog();
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'budget',
              child: Row(
                children: [
                  Icon(Icons.attach_money),
                  SizedBox(width: 8),
                  Text(l10n.budget),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
    body: StreamBuilder<List<types.Message>>(
      initialData: const [],
      stream: _chatController.messages,
      builder: (context, messages) => StreamBuilder<List<types.User>>(
        initialData: const [],
        stream: _chatController.typingUsers,
        builder: (context, users) => StreamBuilder<List<BudgetProposal>>(
          initialData: const [],
          stream: BudgetProposalService.getProposalsStream(widget.room.id), 
          builder: (context, proposals) {
            final messagesList = messages.data ?? [];

            final currentUser = _localUser;

            if (currentUser == null) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // Procesar mensajes personalizados para propuestas de presupuesto
            final processedMessages = messagesList.map((message) {
              if (message is types.CustomMessage &&
                  message.metadata?['type'] == 'budget_proposal') {
                final proposalId = message.metadata?['proposal_id'];
                BudgetProposal? proposal;

                if (proposalId != null && proposals.data != null) {
                  for (var p in proposals.data!) {
                    if (p.id == proposalId) {
                      proposal = p;
                      break;
                    }
                  }
                } 

                if (proposal != null) {
                  // Reemplazar con un widget personalizado para la propuesta
                  return message.copyWith(
                    metadata: {
                      ...message.metadata ?? {},
                      'proposal': proposal.toJson(),
                    },
                  );
                }
              }
              return message;
            }).toList();

            return Stack(
              children: [
                Chat(
                  showUserNames: true,
                  showUserAvatars: true,
                  theme: const DefaultChatTheme(
                    messageMaxWidth: 600,
                  ),
                  l10n: const ChatL10nEs(),
                  typingIndicatorOptions: TypingIndicatorOptions(
                    typingUsers: users.data ?? [],
                  ),
                  isAttachmentUploading: _isAttachmentUploading,
                  messages: processedMessages,
                  onAttachmentPressed: _handleAttachmentPressed,
                  onMessageTap: _handleMessageTap,
                  onPreviewDataFetched: _handlePreviewDataFetched,
                  onSendPressed: _handleSendPressed,
                  user: currentUser,
                  imageHeaders: SupabaseChatCore.instance.httpSupabaseHeaders,
                  onMessageVisibilityChanged: (message, visible) async {
                    if (message.status != types.Status.seen &&
                        message.author.id !=
                            SupabaseChatCore.instance.loggedSupabaseUser!.id) {
                      await SupabaseChatCore.instance.updateMessage(
                        message.copyWith(status: types.Status.seen),
                        widget.room.id,
                      );
                    }
                  },
                  onEndReached: _chatController.loadPreviousMessages,
                  inputOptions: InputOptions(
                    enabled: true,
                    onTextChanged: (text) => _chatController.onTyping(),
                  ),
                  customMessageBuilder: (message, {required messageWidth}) {
                    // 1. Manejo de Propuestas de Presupuesto
                    if (message.metadata?['type'] == 'budget_proposal') {
                      final proposalData = message.metadata?['proposal'];
                      
                      if (proposalData != null) {
                        try {
                          final safeJson = Map<String, dynamic>.from(proposalData as Map);
                          final proposal = BudgetProposal.fromJson(safeJson);
                          
                          // Verificación de seguridad para el usuario
                          final currentUser = _localUser;
                          if (currentUser == null) return const SizedBox.shrink();

                          final amITheWorker = _realUserRole == 'worker';

                          debugPrint('🔎 DEBUG ROL:');
                          debugPrint('👤 Mi ID actual: ${currentUser.id}');
                          debugPrint('📤 ID del Sender (Propuesta): ${proposal.senderId}');

                          return BudgetProposalMessage(
                            proposal: proposal,
                            currentUser: currentUser,
                            amITheWorker: amITheWorker,
                            onAccept: _handleAcceptProposal,
                            onReject: _handleRejectProposal,
                            onCounter: _handleCounterProposal,
                          );
                        } catch (e) {
                          debugPrint('Error al renderizar propuesta: $e');
                          return Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.red[100],
                            child: Text('${l10n.errorShowingProp} $e'),
                          );
                        }
                      }
                    }
                    
                    // 2. Manejo de Confirmación de Servicio
                    else if (message.metadata?['type'] == 'service_completion') {
                      final proposalId = message.metadata?['proposal_id'];
                      if (proposalId != null) {
                        return FutureBuilder<BudgetProposal?>(
                          future: BudgetProposalService.getProposalById(proposalId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(
                                width: 20, 
                                height: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2),
                              );
                            }

                            if (!snapshot.hasData || snapshot.data == null) {
                              return const SizedBox.shrink();
                            }

                            return ServiceCompletionMessage(
                              proposal: snapshot.data!,
                              onServiceUpdated: () {
                                if (mounted) setState(() {});
                              },
                            );
                          },
                        );
                      }
                    }

                    return const SizedBox.shrink();
                  },
                ),

                // Mostrar propuesta pendiente actual si existe
                if (proposals.data != null && proposals.data!.isNotEmpty)
                  _buildActiveProposalIndicator(proposals.data!),
              ],
            );
          },
        ),
      ),
    ),
  );
  }
}
