enum ConversationState {
  idle,
  connecting,
  listening,
  processing,
  speaking,
  error,
}

class ConversationStateData {
  final ConversationState state;
  final DateTime timestamp;
  final String? message;
  final double? confidence;

  ConversationStateData({
    required this.state,
    DateTime? timestamp,
    this.message,
    this.confidence,
  }) : timestamp = timestamp ?? DateTime.now();

  ConversationStateData copyWith({
    ConversationState? state,
    DateTime? timestamp,
    String? message,
    double? confidence,
  }) {
    return ConversationStateData(
      state: state ?? this.state,
      timestamp: timestamp ?? this.timestamp,
      message: message ?? this.message,
      confidence: confidence ?? this.confidence,
    );
  }

  bool get isActive => state != ConversationState.idle && state != ConversationState.error;
  bool get canSpeak => state == ConversationState.listening;
  bool get isAiTurn => state == ConversationState.processing || state == ConversationState.speaking;

  @override
  String toString() => 'ConversationState: ${state.name}${message != null ? ' - $message' : ''}';
}
