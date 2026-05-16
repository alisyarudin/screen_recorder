import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di.dart';
import '../../../data/models/history_entry.dart';

class HistoryState {
  final List<HistoryDay> days;
  final bool isLoading;

  const HistoryState({required this.days, this.isLoading = false});

  HistoryState copyWith({List<HistoryDay>? days, bool? isLoading}) =>
      HistoryState(
        days: days ?? this.days,
        isLoading: isLoading ?? this.isLoading,
      );
}

class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit() : super(const HistoryState(days: []));

  void load({int days = 90}) {
    emit(state.copyWith(isLoading: true));
    final loaded = DI.historyService.getRecentDays(days);
    emit(HistoryState(days: loaded, isLoading: false));
  }

  void reload() => load();
}
