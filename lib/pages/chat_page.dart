import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_quiz_app/controllers/auth_controller.dart';
import 'package:stream_quiz_app/controllers/game.controller.dart';
import 'package:stream_quiz_app/models/quiz_result.dart';
import 'package:stream_quiz_app/repositories/quiz_repository.dart';
import 'package:stream_quiz_app/widgets/widgets.dart';
import 'package:collection/collection.dart';

import '../models/models.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final StreamMessageInputController _messageInputController =
      StreamMessageInputController();

  final GameController gameController = GameController();

  @override
  void dispose() {
    _messageInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(
      value: gameController,
      child: Scaffold(
        appBar: const StreamChannelHeader(),
        body: Column(
          children: <Widget>[
            Expanded(
              child: StreamMessageListView(
                messageBuilder: (_, messageDetails, ___, defaultMessageWidget) {
                  bool hasQuiz = false;
                  if (messageDetails.message.attachments.isNotEmpty &&
                      messageDetails.message.attachments[0].type == 'quiz') {
                    hasQuiz = true;
                  }

                  bool isOwner = messageDetails.message.user ==
                      StreamChat.of(context).currentUser;

                  StreamMessageThemeData? theme;
                  if (hasQuiz) {
                    if (isOwner) {
                      theme = StreamChatTheme.of(context).ownMessageTheme;
                    } else {
                      theme = StreamChatTheme.of(context)
                          .otherMessageTheme
                          .copyWith(messageBackgroundColor: Colors.red);
                    }
                  }

                  return defaultMessageWidget.copyWith(
                    showReactions: false,
                    // messageTheme:
                    //     theme?.copyWith(messageBackgroundColor: Colors.red),
                    customAttachmentBuilders: {
                      'quiz': (_, message, attachments) => MessageBackground(
                            child: QuizStartAttachment(
                              message: message,
                              attachment: attachments[0],
                            ),
                          ),
                      'quiz-question': (_, message, attachments) =>
                          MessageBackground(
                            child: QuizQuestionAttachment(
                              attachment: attachments[0],
                              message: message,
                            ),
                          ),
                      'quiz-result': (_, message, attachments) =>
                          MessageBackground(
                            child: QuizResultAttachment(
                              attachment: attachments[0],
                            ),
                          ),
                    },
                    showEditMessage: false,
                    showFlagButton: false,
                    showReactionPickerIndicator: false,
                  );
                },
              ),
            ),
            StreamMessageInput(messageInputController: _messageInputController),
          ],
        ),
      ),
    );
  }
}

/// Widget to display the final quiz result.
class QuizResultAttachment extends StatefulWidget {
  const QuizResultAttachment({
    Key? key,
    required this.attachment,
  }) : super(key: key);

  final Attachment attachment;

  @override
  State<QuizResultAttachment> createState() => _QuizResultAttachmentState();
}

class _QuizResultAttachmentState extends State<QuizResultAttachment> {
  late final quizResult = QuizResult.fromMap(widget.attachment.extraData);
  late final scores = quizResult.scores;
  late final sortedScoreKeys = _organizeResults();

  List<String> _organizeResults() {
    final sorted = scores.keys.toList()
      ..sort((a, b) {
        final scoreA = scores[a]!;
        final scoreB = scores[b]!;
        return scoreA.compareTo(scoreB);
      });
    return sorted.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    _organizeResults();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'Quiz Result',
            style: Theme.of(context).textTheme.headline6,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Game: ${quizResult.game.quiz.name}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pos',
                style: Theme.of(context).textTheme.caption,
              ),
              Text(
                'Player',
                style: Theme.of(context).textTheme.caption,
              ),
              Text(
                'Score (${quizResult.game.quiz.questions.length})',
                style: Theme.of(context).textTheme.caption,
              ),
            ],
          ),
          ...sortedScoreKeys.map(
            (e) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: UserQuizResult(
                uid: e,
                position: sortedScoreKeys.indexOf(e) + 1,
                score: quizResult.scores[e]!.toDouble(),
              ),
            ),
          )
        ],
      ),
    );
  }
}

/// Display individual [User] quiz result.
class UserQuizResult extends StatelessWidget {
  const UserQuizResult({
    Key? key,
    required this.uid,
    required this.position,
    required this.score,
  }) : super(key: key);

  final String uid;
  final int position;
  final double score;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$position',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        _UserProfilePicture(uid: uid),
        Text(
          score.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// Display a [User] profile picture from [uid].
class _UserProfilePicture extends StatefulWidget {
  const _UserProfilePicture({
    Key? key,
    required this.uid,
  }) : super(key: key);

  final String uid;

  @override
  State<_UserProfilePicture> createState() => _UserProfilePictureState();
}

class _UserProfilePictureState extends State<_UserProfilePicture> {
  late final user = _getUserFromChannel(widget.uid);

  User? _getUserFromChannel(String uid) {
    final member = StreamChannel.of(context)
        .channel
        .state!
        .members
        .firstWhereOrNull((element) => element.userId == uid);
    return member?.user;
  }

  @override
  Widget build(BuildContext context) {
    return StreamUserAvatar(user: user!);
  }
}

/// Widget to display a quiz question.
class QuizQuestionAttachment extends StatefulWidget {
  const QuizQuestionAttachment({
    Key? key,
    required this.attachment,
    required this.message,
  }) : super(key: key);

  final Attachment attachment;
  final Message message;

  @override
  State<QuizQuestionAttachment> createState() => _QuizQuestionAttachmentState();
}

class _QuizQuestionAttachmentState extends State<QuizQuestionAttachment> {
  late final questionMessage =
      QuestionMessage.fromMap(widget.attachment.extraData);
  late final currentQuestion = game.quiz.questions[questionMessage.question];
  late final gameFuture = getGame();
  late final Game game;

  Future<void> getGame() async {
    if (context.read<GameController>().games[questionMessage.gameID] != null) {
      game = context.read<GameController>().games[questionMessage.gameID]!;
    } else {
      game = await context
          .read<QuizRepository>()
          .getGame(questionMessage.gameID) as Game;
      context.read<GameController>().games[questionMessage.gameID] = game;
    }
  }

  Set<String> answers = {};

  void _onSelect(Option option, bool selected) {
    if (selected) {
      answers.add(option.id);
    } else {
      answers.remove(option.id);
    }
  }

  Reaction? getYourAnsweredReaction() {
    return widget.message.ownReactions
        ?.firstWhereOrNull((element) => element.type == 'answered');
  }

  List<Reaction>? getAnsweredReactions() {
    return widget.message.latestReactions
        ?.where((element) => element.type == 'answered')
        .toList();
  }

  bool _hasAnswered() {
    final reaction = getYourAnsweredReaction();
    if (reaction != null) {
      return true;
    } else {
      return false;
    }
  }

  bool _isOwner() {
    return game.host.uid == context.read<AuthController>().user!.uid;
  }

  bool _isLastQuestion() {
    return questionMessage.question == game.quiz.questions.length - 1;
  }

  Future<void> _onNextOrFinish() async {
    if (_isLastQuestion()) {
      final channel = StreamChannel.of(context).channel;
      await context.read<QuizRepository>().endGame(game.id);
      if (mounted) {
        final results =
            await context.read<QuizRepository>().calulateGameResults(game.id);

        await channel.sendMessage(
          Message(
            attachments: [
              Attachment(
                uploadState: const UploadState.success(),
                type: 'quiz-result',
                extraData: results.toMap(),
              ),
            ],
          ),
        );
      }