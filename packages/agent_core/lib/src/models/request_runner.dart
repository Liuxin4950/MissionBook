import 'dart:async';

import '../agent_event.dart';
import '../agent_result.dart';
import '../cancellation.dart';
import '../model.dart';
import 'configuration.dart';

typedef AgentEventSink = FutureOr<void> Function(AgentEvent event);

/// 执行一次逻辑模型请求，可有限重试；每次尝试都有独立的增量与结束状态。
final class ModelRequestRunner {
  ModelRequestRunner({required this.model, required this.retry});
  final AgentModel model;
  final RetryPolicy retry;

  Future<ModelResponse> run(
    ModelRequest request,
    CancellationToken token, {
    int step = 0,
    AgentEventSink? onEvent,
  }) async {
    Future<void> publish(AgentEvent event) async {
      await onEvent?.call(event);
    }

    for (var attempt = 1; ; attempt++) {
      token.throwIfCancelled();
      final partialText = StringBuffer();
      await publish(ModelAttemptStarted(step, attempt, request));
      try {
        if (model is! StreamingAgentModel) {
          return await token.wait(model.complete(request, token));
        }
        final streaming = model as StreamingAgentModel;
        final iterator = StreamIterator(streaming.stream(request, token));
        ModelResponse? response;
        try {
          while (await token.wait(iterator.moveNext())) {
            final update = iterator.current;
            if (response != null) {
              throw const ModelException('invalid_response', '模型在完整结束后继续输出');
            }
            if (update is ModelCompleted) {
              response = update.response;
            } else {
              if (update is ModelTextDelta) partialText.write(update.text);
              await publish(
                ModelStreamUpdated(
                  step,
                  attempt,
                  update,
                  purpose: request.purpose,
                ),
              );
            }
          }
        } finally {
          unawaited(
            iterator.cancel().catchError((Object error) {
              // 取消清理由模型适配器负责；尝试本身已有明确终止状态。
            }),
          );
        }
        if (response == null) {
          throw const ModelException(
            'stream_interrupted',
            '模型没有返回完整结束事件',
            retryable: true,
          );
        }
        return response;
      } on AgentCancelled {
        await publish(
          ModelAttemptFailed(
            step,
            attempt,
            const AgentFailure('cancelled', '模型请求已取消'),
            willRetry: false,
            partialText: partialText.toString(),
            delay: Duration.zero,
          ),
        );
        rethrow;
      } on ModelException catch (error) {
        final willRetry = error.retryable && attempt <= retry.maxRetries;
        var delay = Duration.zero;
        if (willRetry) {
          delay = retry.delayFor(attempt);
          if (error.retryAfter != null && error.retryAfter! > delay) {
            delay = error.retryAfter!;
          }
          if (delay > retry.maxDelay) delay = retry.maxDelay;
        }
        await publish(
          ModelAttemptFailed(
            step,
            attempt,
            AgentFailure(error.code, error.message, cause: error),
            willRetry: willRetry,
            partialText: partialText.toString(),
            delay: delay,
          ),
        );
        if (!willRetry) rethrow;
        await token.delay(delay);
      }
    }
  }
}
