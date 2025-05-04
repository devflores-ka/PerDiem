import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../widgets/room_tile.dart';
import 'room.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  static const _pageSize = 20;

  final PagingController<int, types.Room> _controller =
  PagingController(firstPageKey: 0);

  @override
  void initState() {
    _controller.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int offset) async {
    try {
      final newItems = await SupabaseChatCore.instance
          .rooms(offset: offset, limit: _pageSize);
      final isLastPage = newItems.length < _pageSize;
      if (isLastPage) {
        _controller.appendLastPage(newItems);
      } else {
        final nextPageKey = offset + newItems.length;
        _controller.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _controller.error = error;
    }
  }

  @override
  Widget build(BuildContext context) => Expanded(
    child: RefreshIndicator(
      onRefresh: () async {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _controller.nextPageKey = 0;
            _controller.refresh();
          }
        });
      },
      child: StreamBuilder<List<types.Room>>(
        stream: SupabaseChatCore.instance.roomsUpdates(),
        builder: (context, snapshot) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && snapshot.data != null) {
              _controller.itemList = SupabaseChatCore.updateRoomList(
                _controller.itemList ?? [],
                snapshot.data!,
              );
            }
          });
          return PagedListView<int, types.Room>(
            pagingController: _controller,
            builderDelegate: PagedChildBuilderDelegate<types.Room>(
              itemBuilder: (context, room, index) => RoomTile(
                room: room,
                onTap: (room) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => RoomPage(
                        room: room,
                      ),
                    ),
                  );
                },
              ),
              noItemsFoundIndicatorBuilder: (_) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No se encontraron chats',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
